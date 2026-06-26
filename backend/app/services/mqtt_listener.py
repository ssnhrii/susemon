"""
MQTT Listener — subscribe topic sensor/data dari Gateway LoRa
Alur: terima raw data → simpan DB → AI analisis → broadcast WS → downlink ke node

Sinkronisasi:
  Node Sensor (TA11)  → LoRa SF7 BW125 915MHz → Dragino LG02
  Dragino             → susemon_forward.sh     → MQTT sensor/data
  Backend             → AI Engine              → MQTT sensor/ai_result
  Dragino             → susemon_forward.sh     → LoRa SF7 BW125
  Node Sensor         → receiveDownlink()      → LED + Buzzer + OLED

Downlink format (plain JSON, di-hex oleh Dragino forward script):
  {"node_id":"TA11","status":"AMAN","risk":"LOW","confidence":91}

Node firmware decode: cek `startsWith('{')`, jika tidak → decode hex dulu.
"""
import json
import asyncio
import threading
import logging
import re
from datetime import datetime, timezone

import paho.mqtt.client as mqtt

from app.core.config import settings
from app.core.database import get_pool, get_thresholds
from app.services.ai_engine import analyze_node

logger = logging.getLogger("susemon")

# Regex patterns — dikompilasi sekali di modul level
_RE_NODE_ID  = re.compile(r'^[A-Za-z0-9_\-]{1,20}$')
_RE_HEX_ONLY = re.compile(r'^[0-9a-fA-F]+$')

# Urutan severity status
_STATUS_LEVEL = {"AMAN": 0, "WASPADA": 1, "BERBAHAYA": 2}

_loop: asyncio.AbstractEventLoop = None
_ws_manager = None
_mqtt_client = None

# Hysteresis per node
HYSTERESIS_UP   = 2
HYSTERESIS_DOWN = 3
_last_status: dict    = {}
_signal_counter: dict = {}


def set_ws_manager(manager):
    global _ws_manager
    _ws_manager = manager


def _on_connect(client, userdata, flags, reason_code, properties=None):
    rc = reason_code if isinstance(reason_code, int) else (0 if str(reason_code) == "Success" else 1)
    if rc == 0:
        client.subscribe(settings.MQTT_TOPIC, qos=1)
        logger.info(f"MQTT connected → subscribed '{settings.MQTT_TOPIC}' QoS 1")
    else:
        logger.error(f"MQTT connect failed: {reason_code}")


def _on_disconnect(client, userdata, disconnect_flags, reason_code=None, properties=None):
    rc = reason_code if isinstance(reason_code, int) else (
        0 if reason_code is None or str(reason_code) == "Normal disconnection" else 1
    )
    if rc != 0:
        logger.warning(f"MQTT disconnected ({reason_code}), auto-reconnect aktif...")


def _normalize_timestamp(ts_str: str) -> str:
    """Normalisasi ke UTC ISO8601. Gateway baru kirim UTC (Z), lama +07:00."""
    from datetime import timedelta
    if not ts_str:
        return datetime.now(timezone.utc).isoformat()
    try:
        if ts_str.endswith("+07:00"):
            dt = datetime.fromisoformat(ts_str)
            return (dt.replace(tzinfo=None) - timedelta(hours=7)).replace(
                tzinfo=timezone.utc).isoformat()
        if ts_str.endswith("Z"):
            return ts_str[:-1] + "+00:00"
        if "+" not in ts_str[-6:] and ts_str[-3] != ":":
            return ts_str + "+00:00"
        return ts_str
    except Exception:
        return datetime.now(timezone.utc).isoformat()


def _parse_dragino_payload(raw: dict) -> dict:
    """
    Normalisasi berbagai format payload dari Dragino LG02.

    Format 1 — JSON langsung (script Lua / susemon_forward.sh):
      {"node_id":"TA11","temperature":28.5,"humidity":62.0,"rssi":-85,"timestamp":"..."}
    Format 2 — Wrapper Dragino dengan field "data" berisi JSON string:
      {"rxInfo":{"rssi":-85},"data":"{\"node_id\":\"TA11\",...}"}
    Format 3 — Wrapper dengan "data" berisi hex-encoded JSON:
      {"rxInfo":{"rssi":-85},"data":"7b226e6f64655f6964223a2254413131227d"}
    """
    if "node_id" in raw:
        return raw

    rx_info = raw.get("rxInfo") or raw.get("gatewayInfo") or {}
    if isinstance(rx_info, list):
        rx_info = rx_info[0] if rx_info else {}
    rssi = rx_info.get("rssi") or raw.get("rssi")
    snr  = rx_info.get("snr") or rx_info.get("loRaSNR") or raw.get("snr")

    data_field = raw.get("data") or raw.get("phyPayload")
    if not data_field or not isinstance(data_field, str):
        return raw

    data_str = data_field.strip()

    # Format 3: hex decode
    try:
        decoded_bytes = bytes.fromhex(data_str)
        decoded_json  = json.loads(decoded_bytes.decode("utf-8"))
        if isinstance(decoded_json, dict) and "node_id" in decoded_json:
            if rssi is not None:
                decoded_json.setdefault("rssi", rssi)
            if snr is not None:
                decoded_json.setdefault("snr", snr)
            logger.info(f"Dragino hex decoded: {decoded_json}")
            return decoded_json
    except Exception:
        pass

    # Format 2: JSON string
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
    1. JSON biasa
    2. Dragino LoRaRAW wrapper JSON
    3. Raw hex string
    4. CSV format: NODE,<id>,<temp>,<status>,<hum>
    """
    # Coba sebagai hex string murni (bukan JSON)
    try:
        hex_str = payload_bytes.decode("utf-8").strip()
        if _RE_HEX_ONLY.match(hex_str):
            result = json.loads(bytes.fromhex(hex_str).decode("utf-8"))
            if isinstance(result, dict) and "node_id" in result:
                logger.info(f"Dragino raw hex decoded: {result}")
                return result
    except Exception:
        pass

    # Coba sebagai JSON (langsung atau Dragino wrapper)
    try:
        raw = json.loads(payload_bytes.decode("utf-8"))
        return _parse_dragino_payload(raw)
    except Exception:
        pass

    # Coba decode bytes hex (Dragino kirim bytes bukan string)
    try:
        result = json.loads(bytes.fromhex(payload_bytes.hex()).decode("utf-8"))
        if isinstance(result, dict) and "node_id" in result:
            logger.info(f"Dragino bytes hex decoded: {result}")
            return result
    except Exception:
        pass

    # Coba format CSV
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
    Parse format CSV legacy: NODE,<node_id>,<temp>,<status_str>,<hum>,...
    Contoh: NODE,906,-26.22,Bahaya,0.66
    Humidity dikalikan 100 jika nilainya <= 1.0 (format desimal 0-1).
    """
    parts = [p.strip() for p in text.split(',')]
    if len(parts) < 5 or parts[0].upper() != 'NODE':
        raise ValueError("Bukan format CSV NODE")
    node_id = parts[1]
    try:
        temperature = float(parts[2])
        humidity    = float(parts[4])
        if 0.0 <= humidity <= 1.0:
            humidity = round(humidity * 100, 2)
    except (ValueError, IndexError):
        raise ValueError("Nilai CSV tidak valid")
    return {"node_id": node_id, "temperature": temperature, "humidity": humidity}


def _on_message(client, userdata, msg):
    try:
        raw = _decode_payload(msg.payload)
        logger.info(f"MQTT IN [{msg.topic}]: {raw}")
        raw["timestamp"] = _normalize_timestamp(raw.get("timestamp", ""))
        if _loop and _loop.is_running():
            asyncio.run_coroutine_threadsafe(_process(raw), _loop)
    except Exception as e:
        logger.error(f"MQTT parse error: {e} | payload={msg.payload[:80]}")


async def _process(data: dict):
    """
    Pipeline lengkap per paket MQTT:
    1. Validasi & sanitasi input
    2. Simpan ke DB (status sementara threshold)
    3. Ambil 50 data terakhir
    4. Jalankan AI engine
    5. Hysteresis → status final
    6. Update DB dengan status AI
    7. Buat notifikasi jika anomali (deduplicated 10 menit)
    8. Broadcast ke Flutter via WebSocket
    9. Publish downlink JSON → MQTT → Dragino → LoRa SF7 → Node
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

    # Validasi node_id
    if not _RE_NODE_ID.match(str(node_id)):
        logger.warning(f"MQTT node_id tidak valid: {node_id!r}, diabaikan")
        return

    # Validasi range sensor DHT22
    if not (-40 <= temperature <= 125) or not (0 <= humidity <= 100):
        logger.warning(f"MQTT data out of range: temp={temperature} hum={humidity}, diabaikan")
        return

    # ── 1. Tentukan status awal dari threshold ──
    thresholds = await get_thresholds()
    status_threshold = "AMAN"
    if temperature > thresholds["temp_danger"] or humidity > thresholds["hum_danger"]:
        status_threshold = "BERBAHAYA"
    elif temperature > thresholds["temp_warning"] or humidity > thresholds["hum_warning"]:
        status_threshold = "WASPADA"

    # Parse timestamp
    timestamp_str = data.get("timestamp")
    try:
        dt = datetime.fromisoformat(timestamp_str)
    except Exception:
        dt = datetime.now(timezone.utc)

    # ── 2. Simpan ke DB ──
    pool = await get_pool()
    new_id = None
    try:
        async with pool.acquire() as conn:
            async with conn.cursor() as cur:
                if rssi is not None:
                    await cur.execute(
                        "INSERT INTO sensor_data "
                        "(node_id, temperature, humidity, status, rssi, timestamp) "
                        "VALUES (%s,%s,%s,%s,%s,%s)",
                        (node_id, temperature, humidity, status_threshold, rssi, dt)
                    )
                else:
                    await cur.execute(
                        "INSERT INTO sensor_data "
                        "(node_id, temperature, humidity, status, timestamp) "
                        "VALUES (%s,%s,%s,%s,%s)",
                        (node_id, temperature, humidity, status_threshold, dt)
                    )
                new_id = cur.lastrowid
    except Exception as e:
        logger.error(f"DB insert error: {e}")
        return

    logger.info(f"DB id={new_id}: node={node_id} t={temperature} h={humidity} rssi={rssi}")

    # ── 3. Ambil 50 data terakhir untuk AI ──
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            await cur.execute(
                "SELECT temperature, humidity, timestamp FROM sensor_data "
                "WHERE node_id=%s ORDER BY timestamp DESC LIMIT 50",
                (node_id,)
            )
            rows = await cur.fetchall()

    readings = [{"temperature": r[0], "humidity": r[1], "timestamp": r[2]} for r in rows]
    readings.reverse()  # oldest first

    # ── 4 & 5. Jalankan AI + Hysteresis ──
    ai_result    = None
    final_status = status_threshold

    if len(readings) >= 3:
        ai_result = analyze_node(readings, thresholds)

        if ai_result["overheating_risk"] or ai_result["risk_level"] == "HIGH":
            raw_status = "BERBAHAYA"
        elif ai_result["anomaly_detected"] or ai_result["risk_level"] == "MEDIUM":
            raw_status = "WASPADA"
        else:
            raw_status = "AMAN"

        prev      = _last_status.get(node_id, "AMAN")
        counter   = _signal_counter.get(node_id, 0)
        prev_lvl  = _STATUS_LEVEL.get(prev, 0)
        raw_lvl   = _STATUS_LEVEL.get(raw_status, 0)

        if raw_status == prev:
            _signal_counter[node_id] = 0
            final_status = raw_status
        elif raw_lvl > prev_lvl:
            counter += 1
            _signal_counter[node_id] = counter
            if counter >= HYSTERESIS_UP:
                final_status = raw_status
                _last_status[node_id] = raw_status
                _signal_counter[node_id] = 0
                logger.info(f"Status naik: {prev}→{raw_status} (node={node_id})")
            else:
                final_status = prev
        else:
            counter += 1
            _signal_counter[node_id] = counter
            if counter >= HYSTERESIS_DOWN:
                final_status = raw_status
                _last_status[node_id] = raw_status
                _signal_counter[node_id] = 0
                logger.info(f"Status turun: {prev}→{raw_status} (node={node_id})")
            else:
                final_status = prev

        # ── 6. Update status di DB ──
        if new_id and final_status != status_threshold:
            async with pool.acquire() as conn:
                async with conn.cursor() as cur:
                    await cur.execute(
                        "UPDATE sensor_data SET status=%s WHERE id=%s",
                        (final_status, new_id)
                    )

        # ── 7. Notifikasi (deduplicated 10 menit) ──
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
                        title   = (f"Overheating - {node_id}"
                                   if ai_result["overheating_risk"]
                                   else f"Anomali - {node_id}")
                        message = (ai_result["insights"][0]
                                   if ai_result["insights"]
                                   else f"Confidence: {ai_result['confidence']}%")
                        await cur.execute(
                            "INSERT INTO notifications "
                            "(node_id, title, message, type) VALUES (%s,%s,%s,%s)",
                            (node_id, title, message, ntype)
                        )
                        logger.warning(f"Notifikasi [{ntype.upper()}] {title}")

    # ── 8. Broadcast ke Flutter via WebSocket ──
    if _ws_manager:
        ws_payload = {
            "type":        "sensor_update",
            "node_id":     node_id,
            "temperature": temperature,
            "humidity":    humidity,
            "status":      final_status,
            "rssi":        rssi,
            "timestamp":   data.get("timestamp",
                                    datetime.now(timezone.utc).isoformat()),
        }
        if ai_result:
            ws_payload["ai"] = {
                "anomaly_detected": ai_result["anomaly_detected"],
                "risk_level":       ai_result["risk_level"],
                "confidence":       ai_result["confidence"],
                "predicted_temp":   ai_result.get("predicted_temp"),
                "trend_per_hour":   ai_result.get("trend_per_hour"),
                "trend_direction":  ai_result.get("trend_direction"),
                "overheating_risk": ai_result.get("overheating_risk"),
                "signal_count":     ai_result.get("signal_count", 0),
                "insights":         ai_result.get("insights", []),
            }
        await _ws_manager.broadcast(ws_payload)

    # ── 9. Downlink → MQTT → Dragino → LoRa SF7 → Node ──
    # Node firmware (receiveDownlink) terima plain JSON.
    # susemon_forward.sh hex-encode JSON ini sebelum TX LoRa.
    # Node akan cek: jika tidak starts '{' → decode hex dulu.
    if _mqtt_client:
        downlink = {
            "node_id":    node_id,
            "status":     final_status,
            "risk":       ai_result.get("risk_level", "LOW") if ai_result else "LOW",
            "confidence": ai_result.get("confidence", 0) if ai_result else 0,
        }
        _mqtt_client.publish(
            settings.MQTT_DOWNLINK_TOPIC,
            json.dumps(downlink),
            qos=1,
            retain=False
        )
        logger.info(
            f"Downlink→{node_id}: {final_status} | "
            f"{downlink['risk']} | {downlink['confidence']}%"
        )


def start_mqtt_listener(loop: asyncio.AbstractEventLoop):
    global _loop, _mqtt_client
    _loop = loop

    # Kompatibel paho-mqtt v1 dan v2
    try:
        client = mqtt.Client(
            mqtt.CallbackAPIVersion.VERSION2,
            client_id=settings.MQTT_CLIENT_ID
        )
    except AttributeError:
        client = mqtt.Client(client_id=settings.MQTT_CLIENT_ID)

    client.on_connect    = _on_connect
    client.on_disconnect = _on_disconnect
    client.on_message    = _on_message
    client.reconnect_delay_set(min_delay=2, max_delay=30)

    if settings.MQTT_USER:
        client.username_pw_set(settings.MQTT_USER, settings.MQTT_PASS)

    try:
        client.connect(settings.MQTT_BROKER, settings.MQTT_PORT, keepalive=60)
    except Exception as e:
        logger.error(f"MQTT initial connect error: {e}")

    _mqtt_client = client
    thread = threading.Thread(target=client.loop_forever, daemon=True)
    thread.start()
    logger.info(
        f"MQTT listener → {settings.MQTT_BROKER}:{settings.MQTT_PORT} "
        f"topic_up={settings.MQTT_TOPIC} "
        f"topic_down={settings.MQTT_DOWNLINK_TOPIC}"
    )
    return client
