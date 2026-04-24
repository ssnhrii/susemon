from fastapi import APIRouter, Depends, Query
from typing import Optional
from app.core.database import get_pool
from app.core.security import get_current_user
from app.core.config import settings
from app.services.ai_engine import analyze_node
import logging

router = APIRouter(prefix="/api/ai", tags=["ai"])
logger = logging.getLogger("susemon")

THRESHOLDS = {
    "temp_warning": settings.AI_TEMP_WARNING,
    "temp_danger":  settings.AI_TEMP_DANGER,
    "hum_warning":  settings.AI_HUM_WARNING,
    "hum_danger":   settings.AI_HUM_DANGER,
}


async def _get_readings(node_id: str, limit: int = 50):
    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            await cur.execute(
                "SELECT temperature, humidity, timestamp FROM sensor_data "
                "WHERE node_id=%s ORDER BY timestamp DESC LIMIT %s",
                (node_id, limit)
            )
            rows = await cur.fetchall()
    readings = [{"temperature": r[0], "humidity": r[1], "timestamp": r[2]} for r in rows]
    readings.reverse()  # oldest first
    return readings


async def _maybe_notify(node_id: str, result: dict):
    """Buat notifikasi jika anomali, hindari duplikat 10 menit"""
    if not result.get("anomaly_detected"):
        return
    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            await cur.execute("""
                SELECT id FROM notifications
                WHERE node_id=%s AND type IN ('critical','warning')
                  AND created_at >= DATE_SUB(NOW(), INTERVAL 10 MINUTE)
                LIMIT 1
            """, (node_id,))
            if await cur.fetchone():
                return
            ntype   = "critical" if result["risk_level"] == "HIGH" else "warning"
            title   = f"Overheating - Node {node_id}" if result["overheating_risk"] else f"Anomali - Node {node_id}"
            message = result["insights"][0] if result["insights"] else f"Confidence: {result['confidence']}%"
            await cur.execute(
                "INSERT INTO notifications (node_id, title, message, type) VALUES (%s,%s,%s,%s)",
                (node_id, title, message, ntype)
            )
    logger.warning(f"AI Notifikasi [{ntype.upper()}] {title}")


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.get("/prediction/{node_id}")
async def get_prediction(node_id: str, limit: int = Query(30), user=Depends(get_current_user)):
    readings = await _get_readings(node_id, limit)
    if len(readings) < 3:
        return {"success": True, "data": {"node_id": node_id, "status": "INSUFFICIENT_DATA", "confidence": 0}}

    result = analyze_node(readings, THRESHOLDS)

    # Simpan prediksi
    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            await cur.execute("""
                INSERT INTO ai_predictions (node_id, prediction_type, confidence, predicted_value, prediction_time)
                VALUES (%s,'temperature',%s,%s,DATE_ADD(NOW(), INTERVAL 30 MINUTE))
            """, (node_id, result["confidence"], result.get("predicted_temp")))

    await _maybe_notify(node_id, result)
    return {"success": True, "data": {"node_id": node_id, **result}}


@router.get("/analysis")
async def get_analysis(user=Depends(get_current_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            await cur.execute("SELECT node_id, node_name, location FROM sensor_nodes WHERE is_active=TRUE")
            nodes = await cur.fetchall()

    analysis = []
    for node_id, node_name, location in nodes:
        readings = await _get_readings(node_id, 50)
        if len(readings) < 3:
            analysis.append({"node_id": node_id, "node_name": node_name, "location": location,
                              "status": "INSUFFICIENT_DATA", "anomaly_detected": False,
                              "overheating_risk": False, "confidence": 0})
            continue
        result = analyze_node(readings, THRESHOLDS)
        analysis.append({"node_id": node_id, "node_name": node_name, "location": location, **result})

    analysis.sort(key=lambda x: (not x.get("anomaly_detected", False), -(x.get("current_temp") or 0)))
    return {"success": True, "data": analysis}


@router.get("/summary")
async def get_summary(user=Depends(get_current_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            await cur.execute("SELECT node_id FROM sensor_nodes WHERE is_active=TRUE")
            nodes = [r[0] for r in await cur.fetchall()]

    total_anomaly = 0
    total_overheat = 0
    max_temp = 0.0
    max_node = None

    for node_id in nodes:
        readings = await _get_readings(node_id, 20)
        if len(readings) < 3:
            continue
        result = analyze_node(readings, THRESHOLDS)
        if result["anomaly_detected"]:  total_anomaly += 1
        if result["overheating_risk"]:  total_overheat += 1
        if (result.get("current_temp") or 0) > max_temp:
            max_temp = result["current_temp"]
            max_node = node_id

    global_status = "BERBAHAYA" if total_overheat > 0 else "WASPADA" if total_anomaly > 0 else "AMAN"

    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            await cur.execute("""
                SELECT ROUND(AVG(temperature),2), ROUND(MAX(temperature),2),
                       ROUND(MIN(temperature),2),
                       COUNT(CASE WHEN status='BERBAHAYA' THEN 1 END),
                       COUNT(CASE WHEN status='WASPADA' THEN 1 END)
                FROM sensor_data WHERE timestamp >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
            """)
            row = await cur.fetchone()

    return {
        "success": True,
        "data": {
            "global_status":  global_status,
            "anomaly_count":  total_anomaly,
            "overheat_count": total_overheat,
            "hottest_node":   max_node,
            "hottest_temp":   max_temp,
            "active_nodes":   len(nodes),
            "stats_24h": {
                "avg_temp":      row[0], "max_temp": row[1], "min_temp": row[2],
                "danger_count":  row[3], "warning_count": row[4],
            } if row else {},
        }
    }


@router.get("/history/{node_id}")
async def get_history(node_id: str, limit: int = Query(20), user=Depends(get_current_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            await cur.execute(
                "SELECT * FROM ai_predictions WHERE node_id=%s ORDER BY created_at DESC LIMIT %s",
                (node_id, limit)
            )
            rows = await cur.fetchall()
            cols = [d[0] for d in cur.description]
    return {"success": True, "data": [dict(zip(cols, r)) for r in rows]}


@router.post("/analyze")
async def run_analysis(body: dict = {}, user=Depends(get_current_user)):
    node_id = body.get("node_id")
    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            if node_id:
                await cur.execute("SELECT node_id FROM sensor_nodes WHERE node_id=%s", (node_id,))
            else:
                await cur.execute("SELECT node_id FROM sensor_nodes WHERE is_active=TRUE")
            nodes = [r[0] for r in await cur.fetchall()]

    results = []
    for nid in nodes:
        readings = await _get_readings(nid, 50)
        if len(readings) < 3:
            continue
        result = analyze_node(readings, THRESHOLDS)
        await _maybe_notify(nid, result)
        results.append({"node_id": nid, **result})

    return {"success": True, "message": f"Analisis selesai untuk {len(results)} node", "data": results}
