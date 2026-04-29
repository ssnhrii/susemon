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


def _on_disconnect(client, userdata, rc, properties=None):
    if rc != 0:
        logger.warning(f"MQTT disconnected ({rc}), auto-reconnect aktif...")


def _on_message(client, userdata, msg):
    try:
        raw = json.loads(msg.payload.decode("utf-8"))
        logger.info(f"MQTT IN: {raw}")
        if not raw.get("timestamp"):
            raw["timestamp"] = datetime.now(timezone.utc).isoformat()
        if _loop and _loop.is_running():
            asyncio.run_coroutine_threadsafe(_process(raw), _loop)
    except Exception as e:
        logger.error(f"MQTT parse error: {e} | payload={msg.payload}")


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
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            await cur.execute(
                "INSERT INTO sensor_data (node_id, temperature, humidity, status) VALUES (%s,%s,%s,%s)",
                (node_id, temperature, humidity, status_threshold)
            )
            new_id = cur.lastrowid

    logger.info(f"DB saved id={new_id}: node={node_id} temp={temperature} hum={humidity}")

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

        if raw_status == prev:
            # Status sama → reset counter
            _signal_counter[node_id] = 0
            final_status = raw_status
        elif raw_status > prev or (raw_status == "BERBAHAYA"):
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
            "timestamp":   datetime.now().isoformat(),
        }
        if ai_result:
            ws_payload["ai"] = {
                "anomaly_detected": ai_result["anomaly_detected"],
                "risk_level":       ai_result["risk_level"],
                "confidence":       ai_result["confidence"],
                "predicted_temp":   ai_result.get("predicted_temp"),
                "insights":         ai_result.get("insights", []),
            }
        await _ws_manager.broadcast(ws_payload)

    # ── 7. Publish downlink ke Gateway → Node ──
    if _mqtt_client:
        downlink = {
            "node_id":    node_id,
            "status":     final_status,
            "risk":       ai_result.get("risk_level", "LOW") if ai_result else "LOW",
            "confidence": ai_result.get("confidence", 0) if ai_result else 0,
        }
        _mqtt_client.publish("sensor/ai_result", json.dumps(downlink))
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
