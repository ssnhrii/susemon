"""
MQTT Listener — subscribe topic sensor/data dari Gateway LoRa
Alur: terima raw data → simpan DB → AI analisis → broadcast WS → downlink ke node
"""
import json
import asyncio
import threading
import logging
import re
from datetime import datetime, timezone

import paho.mqtt.client as mqtt

from app.core.config import settings
from app.core.database import get_pool
from app.services.ai_engine import analyze_node

logger = logging.getLogger("susemon")

THRESHOLDS = {
    "temp_warning": settings.AI_TEMP_WARNING,
    "temp_danger":  settings.AI_TEMP_DANGER,
    "hum_warning":  settings.AI_HUM_WARNING,
    "hum_danger":   settings.AI_HUM_DANGER,
}

# Urutan severity status — dipakai untuk perbandingan hysteresis
_STATUS_LEVEL = {"AMAN": 0, "WASPADA": 1, "BERBAHAYA": 2}

_loop: asyncio.AbstractEventLoop = None
_ws_manager = None
_mqtt_client = None

# ── Hysteresis: simpan status terakhir per node ───────────────────────────────
# Mencegah status bolak-balik di zona abu-abu
_last_status: dict = {}   # {node_id: "AMAN"|"WASPADA"|"BERBAHAYA"}

# Jumlah sinyal minimum untuk naik/turun status
HYSTERESIS_UP   = 2   # butuh 2x sinyal berturut untuk naik ke WASPADA/BERBAHAYA
HYSTERESIS_DOWN = 3   # butuh 3x sinyal berturut untuk turun ke AMAN
_signal_counter: dict = {}  # {node_id: int}


def set_ws_manager(manager):
    global _ws_manager
    _ws_manager = manager


def _on_connect(client, userdata, flags, reason_code, properties=None):
    # Kompatibel v1 (rc int) dan v2 (ReasonCode object)
    rc = reason_code if isinstance(reason_code, int) else (0 if str(reason_code) == "Success" else 1)
    if rc == 0:
        client.subscribe(settings.MQTT_TOPIC)
        logger.info(f"MQTT connected → subscribed '{settings.MQTT_TOPIC}'")
    else:
        logger.error(f"MQTT connect failed: {reason_code}")


def _on_disconnect(client, userdata, disconnect_flags, reason_code=None, properties=None):
    rc = reason_code if isinstance(reason_code, int) else (0 if reason_code is None or str(reason_code) == "Normal disconnection" else 1)
    if rc != 0:
        logger.warning(f"MQTT disconnected ({reason_code}), auto-reconnect aktif...")


def _normalize_timestamp(ts_str: str) -> str:
    """Normalisasi timestamp ke UTC ISO8601. Gateway baru kirim UTC (Z), gateway lama kirim +07:00."""
    from datetime import timedelta
    if not ts_str:
        return datetime.now(timezone.utc).isoformat()
    try:
        if ts_str.endswith("+07:00"):
            # Gateway lama — konversi WIB ke UTC
            dt = datetime.fromisoformat(ts_str)
            return (dt.replace(tzinfo=None) - timedelta(hours=7)).replace(tzinfo=timezone.utc).isoformat()
        if ts_str.endswith("Z"):
            return ts_str[:-1] + "+00:00"
        # Tidak ada timezone info → anggap UTC
        if "+" not in ts_str[-6:] and ts_str[-3] != ":":
            return ts_str + "+00:00"
        return ts_str
    except Exception:
        return datetime.now(timezone.utc).isoformat()


def _parse_dragino_payload(raw: dict) -> dict:
    """
    Normalisasi berbagai format payload dari Dragino LG02.

    Dragino bisa kirim dalam 3 format tergantung firmware & konfigurasi:
    1. JSON langsung dari Lua script (format baru — script dragino_gateway_script.lua):
       {"node_id":"TA11","temperature":28.5,"humidity":62.0,"rssi":-85,"snr":9.5,"timestamp":"..."}
    2. Wrapper Dragino dengan field "data" berisi JSON string (base64 atau plain):
       {"rxInfo":{"rssi":-85,"snr":9.5},"data":"{\"node_id\":\"TA11\",...}"}
    3. Wrapper Dragino dengan field "data" berisi hex-encoded JSON (format lama):
       {"rxInfo":{"rssi":-85},"data":"7b226e6f64655f6964223a2254413131227d"}
    """
    # Format 1: sudah ada node_id → sudah bersih, ambil rssi/snr dari root jika ada
    if "node_id" in raw:
        return raw

    # Ekstrak rssi/snr dari rxInfo (format Dragino standar)
    rx_info = raw.get("rxInfo") or raw.get("gatewayInfo") or {}
    if isinstance(rx_info, list):
        rx_info = rx_info[0] if rx_info else {}
    rssi = rx_info.get("rssi") or raw.get("rssi")
    snr  = rx_info.get("snr")  or rx_info.get("loRaSNR") or raw.get("snr")

    data_field = raw.get("data") or raw.get("phyPayload")
    if not data_field or not isinstance(data_field, str):
        return raw

    data_str = data_field.strip()

    # Format 3: coba decode hex
    try:
        decoded_bytes = bytes.fromhex(data_str)
        decoded_str   = decoded_bytes.decode("utf-8")
        decoded_json  = json.loads(decoded_str)
        if isinstance(decoded_json, dict) and "node_id" in decoded_json:
            if rssi is not None:
                decoded_json.setdefault("rssi", rssi)
            if snr is not None:
                decoded_json.setdefault("snr", snr)
            logger.info(f"Dragino hex decoded: {decoded_json}")
            return decoded_json
    except Exception:
        pass

    # Format 2: coba parse JSON string langsung
    try:
        decoded_json = json.loads(data_str)
        if isinstance(decoded_json, dict) and "node_id" in decoded_json:
            if rssi is not None:
                decoded_json.setdefault("rssi", rssi)
            if snr is not None:
                decoded_json.setdefault("snr", snr)
            logger.info(f"Dragino JSON string decoded: {decoded_json}")
            return decoded_json
    except Exception:
        pass

    logger.warning(f"Dragino payload tidak dapat di-decode: {data_str[:80]}")
    return raw


def _decode_payload(payload_bytes: bytes) -> dict:
    """
    Decode payload MQTT dari berbagai sumber:
    1. JSON biasa: {"node_id":"TA11","temperature":28.5,...}
    2. Dragino LoRaRAW wrapper JSON: {"data":"7b226e6f...","rxInfo":{...}}
    3. Dragino raw hex string: 7b226e6f64655f6964223a...
    4. Dragino raw bytes (langsung JSON sebagai bytes)
    """
    # Coba sebagai hex string murni (bukan JSON)
    try:
        hex_str = payload_bytes.decode("utf-8").strip()
        if re.match(r'^[0-9a-fA-F]+$', hex_str):
            decoded = bytes.fromhex(hex_str).decode("utf-8")
            result = json.loads(decoded)
            if isinstance(result, dict) and "node_id" in result:
                logger.info(f"Dragino raw hex decoded: {result}")
                return result
    except Exception:
        pass

    # Coba sebagai JSON
    try:
        raw = json.loads(payload_bytes.decode("utf-8"))
        return _parse_dragino_payload(raw)
    except Exception:
        pass

    # Coba decode bytes langsung sebagai hex (Dragino kirim bytes bukan string)
    try:
        hex_str = payload_bytes.hex()
        decoded = bytes.fromhex(hex_str).decode("utf-8")
        result = json.loads(decoded)
        if isinstance(result, dict) and "node_id" in result:
            logger.info(f"Dragino bytes hex decoded: {result}")
            return result
    except Exception:
        pass

    # Coba format CSV: NODE,<id>,<temp>,<status>,<hum>,...
    try:
        text = payload_bytes.decode("utf-8").strip()
        result = _parse_csv_payload(text)
        logger.info(f"CSV payload decoded: {result}")
        return result
    except Exception:
        pass

    raise ValueError(f"Tidak bisa decode payload: {payload_bytes[:80]}")


def _parse_csv_payload(text: str) -> dict:
    """
    Parse format CSV dari node sensor lain (backup/legacy):
    NODE,<node_id>,<temperature>,<status_str>,<humidity>,...
    Contoh: NODE,906,-26.22,Bahaya,0.66,0.000000,0.000000
    Humidity dikalikan 100 jika nilainya <= 1.0 (format desimal 0-1)
    """
    parts = [p.strip() for p in text.split(',')]
    if len(parts) < 5 or parts[0].upper() != 'NODE':
        raise ValueError("Bukan format CSV NODE")
    node_id = parts[1]
    try:
        temperature = float(parts[2])
        humidity    = float(parts[4])
        # Konversi jika humidity dalam format 0-1
        if 0.0 <= humidity <= 1.0:
            humidity = round(humidity * 100, 2)
    except (ValueError, IndexError):
        raise ValueError("Nilai CSV tidak valid")
    return {
        "node_id":     node_id,
        "temperature": temperature,
        "humidity":    humidity,
    }


def _on_message(client, userdata, msg):
    try:
        raw = _decode_payload(msg.payload)
        logger.info(f"MQTT IN: {raw}")
        raw["timestamp"] = _normalize_timestamp(raw.get("timestamp", ""))
        if _loop and _loop.is_running():
            asyncio.run_coroutine_threadsafe(_process(raw), _loop)
    except Exception as e:
        logger.error(f"MQTT parse error: {e} | payload={msg.payload[:80]}")


async def _process(data: dict):
    """
    Pipeline lengkap:
    1. Simpan data mentah ke DB (status sementara dari threshold)
    2. Ambil 50 data terakhir
    3. Jalankan AI → hasil final
    4. Update status di DB dengan hasil AI
    5. Buat notifikasi jika anomali
    6. Broadcast ke Flutter via WebSocket
    7. Publish downlink ke Gateway → Node (LED & Buzzer)
    """
    node_id     = data.get("node_id")
    temperature = float(data.get("temperature", 0))
    humidity    = float(data.get("humidity", 0))
    rssi        = data.get("rssi")
    if rssi is not None:
        try:
            rssi = int(rssi)
        except (ValueError, TypeError):
            rssi = None

    if not node_id:
        logger.warning("MQTT data tanpa node_id, diabaikan")
        return

    # Validasi node_id — hanya alfanumerik + dash/underscore, max 20 karakter
    if not re.match(r'^[A-Za-z0-9_\-]{1,20}$', str(node_id)):
        logger.warning(f"MQTT node_id tidak valid: {node_id!r}, diabaikan")
        return

    # Validasi range sensor
    if not (-40 <= temperature <= 125) or not (0 <= humidity <= 100):
        logger.warning(f"MQTT data out of range: temp={temperature} hum={humidity}, diabaikan")
        return

    # ── 1. Simpan data mentah ke DB ──
    # Status awal dari threshold (akan diupdate setelah AI)
    status_threshold = "AMAN"
    if temperature > THRESHOLDS["temp_danger"] or humidity > THRESHOLDS["hum_danger"]:
        status_threshold = "BERBAHAYA"
    elif temperature > THRESHOLDS["temp_warning"] or humidity > THRESHOLDS["hum_warning"]:
        status_threshold = "WASPADA"

    pool = await get_pool()
    new_id = None
    try:
        async with pool.acquire() as conn:
            async with conn.cursor() as cur:
                if rssi is not None:
                    await cur.execute(
                        "INSERT INTO sensor_data (node_id, temperature, humidity, status, rssi) VALUES (%s,%s,%s,%s,%s)",
                        (node_id, temperature, humidity, status_threshold, rssi)
                    )
                else:
                    await cur.execute(
                        "INSERT INTO sensor_data (node_id, temperature, humidity, status) VALUES (%s,%s,%s,%s)",
                        (node_id, temperature, humidity, status_threshold)
                    )
                new_id = cur.lastrowid
    except Exception as e:
        logger.error(f"DB insert error: {e}")
        return

    logger.info(f"DB saved id={new_id}: node={node_id} temp={temperature} hum={humidity} rssi={rssi}")

    # ── 2. Ambil 50 data terakhir untuk AI ──
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            await cur.execute(
                "SELECT temperature, humidity, timestamp FROM sensor_data "
                "WHERE node_id=%s ORDER BY timestamp DESC LIMIT 50",
                (node_id,)
            )
            rows = await cur.fetchall()

    readings = [{"temperature": r[0], "humidity": r[1], "timestamp": r[2]} for r in rows]
    readings.reverse()  # oldest first untuk analisis tren

    # ── 3. Jalankan AI ──
    ai_result = None
    final_status = status_threshold  # fallback ke threshold jika data kurang

    if len(readings) >= 3:
        ai_result = analyze_node(readings, THRESHOLDS)

        # Status raw dari AI
        if ai_result["overheating_risk"] or ai_result["risk_level"] == "HIGH":
            raw_status = "BERBAHAYA"
        elif ai_result["anomaly_detected"] or ai_result["risk_level"] == "MEDIUM":
            raw_status = "WASPADA"
        else:
            raw_status = "AMAN"

        # ── Hysteresis: cegah status bolak-balik ──
        prev = _last_status.get(node_id, "AMAN")
        counter = _signal_counter.get(node_id, 0)

        prev_level = _STATUS_LEVEL.get(prev, 0)
        raw_level  = _STATUS_LEVEL.get(raw_status, 0)

        if raw_status == prev:
            # Status sama → reset counter
            _signal_counter[node_id] = 0
            final_status = raw_status
        elif raw_level > prev_level:
            # Naik status (AMAN→WASPADA atau WASPADA→BERBAHAYA)
            counter += 1
            _signal_counter[node_id] = counter
            if counter >= HYSTERESIS_UP:
                final_status = raw_status
                _last_status[node_id] = raw_status
                _signal_counter[node_id] = 0
                logger.info(f"Status naik: {prev} → {raw_status} (node={node_id})")
            else:
                final_status = prev  # tahan status lama
        else:
            # Turun status (BERBAHAYA→WASPADA atau WASPADA→AMAN)
            counter += 1
            _signal_counter[node_id] = counter
            if counter >= HYSTERESIS_DOWN:
                final_status = raw_status
                _last_status[node_id] = raw_status
                _signal_counter[node_id] = 0
                logger.info(f"Status turun: {prev} → {raw_status} (node={node_id})")
            else:
                final_status = prev  # tahan status lama

        # ── 4. Update status di DB dengan hasil AI ──
        if new_id and final_status != status_threshold:
            async with pool.acquire() as conn:
                async with conn.cursor() as cur:
                    await cur.execute(
                        "UPDATE sensor_data SET status=%s WHERE id=%s",
                        (final_status, new_id)
                    )

        # ── 5. Buat notifikasi jika anomali (hindari duplikat 10 menit) ──
        if ai_result["anomaly_detected"]:
            async with pool.acquire() as conn:
                async with conn.cursor() as cur:
                    await cur.execute("""
                        SELECT id FROM notifications
                        WHERE node_id=%s AND type IN ('critical','warning')
                          AND created_at >= DATE_SUB(NOW(), INTERVAL 10 MINUTE)
                        LIMIT 1
                    """, (node_id,))
                    if not await cur.fetchone():
                        ntype   = "critical" if final_status == "BERBAHAYA" else "warning"
                        title   = f"Overheating - {node_id}" if ai_result["overheating_risk"] else f"Anomali - {node_id}"
                        message = ai_result["insights"][0] if ai_result["insights"] else f"Confidence: {ai_result['confidence']}%"
                        await cur.execute(
                            "INSERT INTO notifications (node_id, title, message, type) VALUES (%s,%s,%s,%s)",
                            (node_id, title, message, ntype)
                        )
                        logger.warning(f"AI [{ntype.upper()}] {title}")

    # ── 6. Broadcast ke Flutter via WebSocket ──
    if _ws_manager:
        ws_payload = {
            "type":        "sensor_update",
            "node_id":     node_id,
            "temperature": temperature,
            "humidity":    humidity,
            "status":      final_status,
            "rssi":        rssi,
            "timestamp":   data.get("timestamp", datetime.now(timezone.utc).isoformat()),
        }
        if ai_result:
            ws_payload["ai"] = {
                "anomaly_detected":       ai_result["anomaly_detected"],
                "risk_level":             ai_result["risk_level"],
                "confidence":             ai_result["confidence"],
                "predicted_temp":         ai_result.get("predicted_temp"),
                "trend_per_hour":         ai_result.get("trend_per_hour"),
                "trend_direction":        ai_result.get("trend_direction"),
                "overheating_risk":       ai_result.get("overheating_risk"),
                "signal_count":           ai_result.get("signal_count", 0),
                "insights":               ai_result.get("insights", []),
            }
        await _ws_manager.broadcast(ws_payload)

    # ── 7. Publish downlink ke Gateway → Node ──
    # Format plain JSON — Dragino LG02 Lua script (dragino_gateway_script.lua)
    # akan subscribe topic ini dan re-transmit via LoRa ke node
    if _mqtt_client:
        downlink = {
            "node_id":    node_id,
            "status":     final_status,
            "risk":       ai_result.get("risk_level", "LOW") if ai_result else "LOW",
            "confidence": ai_result.get("confidence", 0) if ai_result else 0,
        }
        _mqtt_client.publish(settings.MQTT_DOWNLINK_TOPIC, json.dumps(downlink))
        logger.info(f"Downlink → {node_id}: {final_status} | {downlink['risk']} | {downlink['confidence']}%")


def start_mqtt_listener(loop: asyncio.AbstractEventLoop):
    global _loop, _mqtt_client
    _loop = loop

    # Kompatibel paho-mqtt v1 dan v2
    try:
        # v2: pakai CallbackAPIVersion
        client = mqtt.Client(
            mqtt.CallbackAPIVersion.VERSION2,
            client_id=settings.MQTT_CLIENT_ID
        )
    except AttributeError:
        # v1: tidak ada CallbackAPIVersion
        client = mqtt.Client(client_id=settings.MQTT_CLIENT_ID)

    client.on_connect    = _on_connect
    client.on_disconnect = _on_disconnect
    client.on_message    = _on_message
    client.reconnect_delay_set(min_delay=2, max_delay=30)

    # Set credentials jika dikonfigurasi
    if settings.MQTT_USER:
        client.username_pw_set(settings.MQTT_USER, settings.MQTT_PASS)

    try:
        client.connect(settings.MQTT_BROKER, settings.MQTT_PORT, keepalive=60)
    except Exception as e:
        logger.error(f"MQTT initial connect error: {e}")

    _mqtt_client = client

    thread = threading.Thread(target=client.loop_forever, daemon=True)
    thread.start()
    logger.info(f"MQTT listener → {settings.MQTT_BROKER}:{settings.MQTT_PORT} topic={settings.MQTT_TOPIC}")
    return client
