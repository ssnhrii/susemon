import asyncio
import json
import logging
from contextlib import asynccontextmanager
from datetime import datetime

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.core.database import init_db, close_pool, get_pool
from app.routers import auth, sensors, notifications, ai as ai_router
from app.services.ai_engine import analyze_node
from app.services.mqtt_listener import start_mqtt_listener, set_ws_manager

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s"
)
logger = logging.getLogger("susemon")

# ── WebSocket Manager ─────────────────────────────────────────────────────────

class ConnectionManager:
    def __init__(self):
        self.active: list[WebSocket] = []

    async def connect(self, ws: WebSocket):
        await ws.accept()
        self.active.append(ws)
        logger.info(f"WS connected. Total: {len(self.active)}")

    def disconnect(self, ws: WebSocket):
        self.active.remove(ws)
        logger.info(f"WS disconnected. Total: {len(self.active)}")

    async def broadcast(self, data: dict):
        msg = json.dumps(data, default=str)
        dead = []
        for ws in self.active:
            try:
                await ws.send_text(msg)
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.active.remove(ws)

manager = ConnectionManager()

# ── Background tasks ──────────────────────────────────────────────────────────

async def broadcast_sensor_data():
    """Kirim data sensor terbaru ke semua WS client setiap 3 detik"""
    while True:
        await asyncio.sleep(3)
        if not manager.active:
            continue
        try:
            pool = await get_pool()
            async with pool.acquire() as conn:
                async with conn.cursor() as cur:
                    await cur.execute("""
                        SELECT sd.*, sn.node_name, sn.location
                        FROM sensor_data sd
                        INNER JOIN sensor_nodes sn ON sd.node_id=sn.node_id
                        WHERE sd.timestamp=(
                            SELECT MAX(timestamp) FROM sensor_data WHERE node_id=sd.node_id
                        )
                        ORDER BY sd.node_id
                    """)
                    rows = await cur.fetchall()
                    cols = [d[0] for d in cur.description]
            data = [dict(zip(cols, r)) for r in rows]
            await manager.broadcast({
                "type": "sensor_update",
                "data": data,
                "timestamp": datetime.now().isoformat()
            })
        except Exception as e:
            logger.error(f"Broadcast error: {e}")


THRESHOLDS = {
    "temp_warning": settings.AI_TEMP_WARNING,
    "temp_danger":  settings.AI_TEMP_DANGER,
    "hum_warning":  settings.AI_HUM_WARNING,
    "hum_danger":   settings.AI_HUM_DANGER,
}

async def auto_ai_scan():
    """Jalankan AI scan setiap 5 menit"""
    await asyncio.sleep(10)  # tunggu 10 detik setelah startup
    while True:
        try:
            pool = await get_pool()
            async with pool.acquire() as conn:
                async with conn.cursor() as cur:
                    await cur.execute("SELECT node_id FROM sensor_nodes WHERE is_active=TRUE")
                    nodes = [r[0] for r in await cur.fetchall()]

            anomaly_count = 0
            for node_id in nodes:
                async with pool.acquire() as conn:
                    async with conn.cursor() as cur:
                        await cur.execute(
                            "SELECT temperature, humidity, timestamp FROM sensor_data "
                            "WHERE node_id=%s ORDER BY timestamp DESC LIMIT 50",
                            (node_id,)
                        )
                        rows = await cur.fetchall()

                readings = [{"temperature": r[0], "humidity": r[1], "timestamp": r[2]} for r in rows]
                readings.reverse()
                if len(readings) < 3:
                    continue

                result = analyze_node(readings, THRESHOLDS)
                if result["anomaly_detected"]:
                    anomaly_count += 1
                    # Cek duplikat notifikasi
                    async with pool.acquire() as conn:
                        async with conn.cursor() as cur:
                            await cur.execute("""
                                SELECT id FROM notifications
                                WHERE node_id=%s AND type IN ('critical','warning')
                                  AND created_at >= DATE_SUB(NOW(), INTERVAL 10 MINUTE)
                                LIMIT 1
                            """, (node_id,))
                            if not await cur.fetchone():
                                ntype   = "critical" if result["risk_level"] == "HIGH" else "warning"
                                title   = f"Overheating - Node {node_id}" if result["overheating_risk"] else f"Anomali - Node {node_id}"
                                message = result["insights"][0] if result["insights"] else f"Confidence: {result['confidence']}%"
                                await cur.execute(
                                    "INSERT INTO notifications (node_id, title, message, type) VALUES (%s,%s,%s,%s)",
                                    (node_id, title, message, ntype)
                                )

                    # Broadcast AI alert
                    await manager.broadcast({
                        "type": "ai_alert",
                        "node_id": node_id,
                        "risk_level": result["risk_level"],
                        "confidence": result["confidence"],
                        "insights": result["insights"],
                        "timestamp": datetime.now().isoformat()
                    })

            if anomaly_count > 0:
                logger.warning(f"AI Auto-scan: {anomaly_count} anomali terdeteksi")

        except Exception as e:
            logger.error(f"Auto AI error: {e}")

        await asyncio.sleep(5 * 60)  # 5 menit


# ── Lifespan ──────────────────────────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()

    # Daftarkan WebSocket manager ke MQTT listener
    set_ws_manager(manager)

    # Start MQTT listener (subscribe sensor/data dari Gateway)
    loop = asyncio.get_event_loop()
    start_mqtt_listener(loop)

    # Background tasks
    t1 = asyncio.create_task(broadcast_sensor_data())
    t2 = asyncio.create_task(auto_ai_scan())
    logger.info("SUSEMON FastAPI started")
    yield
    t1.cancel()
    t2.cancel()
    await close_pool()
    logger.info("SUSEMON FastAPI stopped")


# ── App ───────────────────────────────────────────────────────────────────────

app = FastAPI(
    title="SUSEMON API",
    description="Smart Server Room Monitoring — PBL-TRPL412",
    version="2.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(sensors.router)
app.include_router(notifications.router)
app.include_router(ai_router.router)


@app.get("/api/health")
async def health():
    return {"success": True, "message": "SUSEMON FastAPI is running",
            "timestamp": datetime.now().isoformat()}


@app.websocket("/ws")
async def websocket_endpoint(ws: WebSocket):
    await manager.connect(ws)
    await ws.send_text(json.dumps({
        "type": "connection",
        "message": "Connected to SUSEMON WebSocket",
        "timestamp": datetime.now().isoformat()
    }))
    try:
        while True:
            await ws.receive_text()  # keep alive
    except WebSocketDisconnect:
        manager.disconnect(ws)
