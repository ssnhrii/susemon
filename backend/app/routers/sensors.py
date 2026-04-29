from fastapi import APIRouter, Depends, Query, HTTPException
from typing import Optional
from app.core.database import get_pool
from app.core.security import get_current_user, verify_gateway_key
from app.models.schemas import SensorDataIn

router = APIRouter(prefix="/api/sensors", tags=["sensors"])


@router.get("/nodes")
async def get_nodes(user=Depends(get_current_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            await cur.execute("""
                SELECT sn.*,
                  (SELECT temperature FROM sensor_data WHERE node_id=sn.node_id ORDER BY timestamp DESC LIMIT 1) as current_temp,
                  (SELECT humidity    FROM sensor_data WHERE node_id=sn.node_id ORDER BY timestamp DESC LIMIT 1) as current_humidity,
                  (SELECT status      FROM sensor_data WHERE node_id=sn.node_id ORDER BY timestamp DESC LIMIT 1) as current_status
                FROM sensor_nodes sn WHERE is_active=TRUE
            """)
            rows = await cur.fetchall()
            cols = [d[0] for d in cur.description]
    return {"success": True, "data": [dict(zip(cols, r)) for r in rows]}


@router.get("/latest")
async def get_latest(user=Depends(get_current_user)):
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
    return {"success": True, "data": [dict(zip(cols, r)) for r in rows]}


@router.get("/data/{node_id}")
async def get_sensor_data(
    node_id: str,
    limit: int = Query(20, ge=1, le=500),
    period: str = Query("24h"),
    user=Depends(get_current_user)
):
    # Validasi node_id — hanya alfanumerik + dash/underscore
    import re
    if not re.match(r'^[A-Za-z0-9_\-]{1,20}$', node_id):
        raise HTTPException(status_code=400, detail="node_id tidak valid")
    time_filter = {
        "24h": "AND timestamp >= DATE_SUB(NOW(), INTERVAL 24 HOUR)",
        "7d":  "AND timestamp >= DATE_SUB(NOW(), INTERVAL 7 DAY)",
        "30d": "AND timestamp >= DATE_SUB(NOW(), INTERVAL 30 DAY)",
    }.get(period, "")

    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            await cur.execute(
                f"SELECT * FROM sensor_data WHERE node_id=%s {time_filter} ORDER BY timestamp DESC LIMIT %s",
                (node_id, limit)
            )
            rows = await cur.fetchall()
            cols = [d[0] for d in cur.description]
    data = [dict(zip(cols, r)) for r in rows]
    data.reverse()  # oldest first
    return {"success": True, "data": data}


@router.get("/statistics")
async def get_statistics(
    period: str = Query("24h"),
    user=Depends(get_current_user)
):
    time_map = {
        "24h": "DATE_SUB(NOW(), INTERVAL 24 HOUR)",
        "7d":  "DATE_SUB(NOW(), INTERVAL 7 DAY)",
        "30d": "DATE_SUB(NOW(), INTERVAL 30 DAY)",
    }
    time_filter = time_map.get(period, time_map["24h"])

    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            await cur.execute(f"""
                SELECT
                  ROUND(AVG(temperature),2) as avg_temp,
                  ROUND(MAX(temperature),2) as max_temp,
                  ROUND(MIN(temperature),2) as min_temp,
                  ROUND(AVG(humidity),2)    as avg_humidity,
                  COUNT(CASE WHEN status='BERBAHAYA' THEN 1 END) as danger_count,
                  COUNT(CASE WHEN status='WASPADA'   THEN 1 END) as warning_count,
                  COUNT(CASE WHEN status='AMAN'      THEN 1 END) as safe_count
                FROM sensor_data WHERE timestamp >= {time_filter}
            """)
            row  = await cur.fetchone()
            cols = [d[0] for d in cur.description]
    return {"success": True, "data": dict(zip(cols, row)) if row else {}}


@router.post("/data")
async def add_sensor_data(body: SensorDataIn, _=Depends(verify_gateway_key)):
    """Endpoint untuk LoRa gateway — dilindungi API key (X-Api-Key header)"""
    from app.core.config import settings
    status = "AMAN"
    if body.temperature > settings.AI_TEMP_DANGER or body.humidity > settings.AI_HUM_DANGER:
        status = "BERBAHAYA"
    elif body.temperature > settings.AI_TEMP_WARNING or body.humidity > settings.AI_HUM_WARNING:
        status = "WASPADA"

    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            await cur.execute(
                "INSERT INTO sensor_data (node_id, temperature, humidity, status) VALUES (%s,%s,%s,%s)",
                (body.node_id, body.temperature, body.humidity, status)
            )
            if status == "BERBAHAYA":
                await cur.execute(
                    "INSERT INTO notifications (node_id, title, message, type) VALUES (%s,%s,%s,'critical')",
                    (body.node_id,
                     f"Peringatan {status} - {body.node_id}",
                     f"Suhu {body.temperature}°C, Kelembapan {body.humidity}% pada node {body.node_id}")
                )

    return {"success": True, "message": "Data berhasil disimpan",
            "data": {"node_id": body.node_id, "temperature": body.temperature,
                     "humidity": body.humidity, "status": status}}
