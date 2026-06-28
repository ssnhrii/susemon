"""
Sensors Router — CRUD data sensor + export CSV
Regex dan validasi sinkron dengan mqtt_listener.py dan schemas.py
"""
import re
import io
import csv
from fastapi import APIRouter, Depends, Query, HTTPException, Body
from fastapi.responses import StreamingResponse
from app.core.database import get_pool, get_thresholds, update_thresholds
from app.core.security import get_current_user, verify_gateway_key, require_pic_or_admin
from app.models.schemas import SensorDataIn, SensorNodeCreate, SensorNodeUpdate

router = APIRouter(prefix="/api/sensors", tags=["sensors"])

# Regex dikompilasi sekali — sinkron dengan mqtt_listener._RE_NODE_ID
_VALID_NODE_ID = re.compile(r'^[A-Za-z0-9_\-]{1,20}$')

_TIME_FILTERS = {
    "1h":  "AND timestamp >= DATE_SUB(NOW(), INTERVAL 1 HOUR)",
    "6h":  "AND timestamp >= DATE_SUB(NOW(), INTERVAL 6 HOUR)",
    "24h": "AND timestamp >= DATE_SUB(NOW(), INTERVAL 24 HOUR)",
    "7d":  "AND timestamp >= DATE_SUB(NOW(), INTERVAL 7 DAY)",
    "30d": "AND timestamp >= DATE_SUB(NOW(), INTERVAL 30 DAY)",
}


@router.get("/nodes")
async def get_nodes(user=Depends(get_current_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            await cur.execute("""
                SELECT sn.*,
                  (SELECT temperature FROM sensor_data WHERE node_id=sn.node_id
                   ORDER BY timestamp DESC LIMIT 1) AS current_temp,
                  (SELECT humidity    FROM sensor_data WHERE node_id=sn.node_id
                   ORDER BY timestamp DESC LIMIT 1) AS current_humidity,
                  (SELECT status      FROM sensor_data WHERE node_id=sn.node_id
                   ORDER BY timestamp DESC LIMIT 1) AS current_status,
                  (SELECT timestamp   FROM sensor_data WHERE node_id=sn.node_id
                   ORDER BY timestamp DESC LIMIT 1) AS last_seen,
                  (SELECT rssi        FROM sensor_data WHERE node_id=sn.node_id
                   ORDER BY timestamp DESC LIMIT 1) AS last_rssi
                FROM sensor_nodes sn
                WHERE sn.is_active=TRUE
                ORDER BY sn.node_id
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
    limit: int = Query(50, ge=1, le=1000),
    period: str = Query("24h"),
    user=Depends(get_current_user)
):
    if not _VALID_NODE_ID.match(node_id):
        raise HTTPException(status_code=400, detail="node_id tidak valid")
    time_filter = _TIME_FILTERS.get(period, _TIME_FILTERS["24h"])
    pool = await get_pool()

    if period in ("6h", "24h", "7d", "30d"):
        # Downsampling — interval sesuai periode agar chart tidak terlalu padat
        interval_map = {"6h": 60, "24h": 300, "7d": 3600, "30d": 3600}
        points_map   = {"6h": 360, "24h": 288, "7d": 168, "30d": 720}
        interval_seconds = interval_map[period]
        required_points  = points_map[period]
        query_limit = max(limit, required_points)

        sql = f"""
            SELECT
              MIN(id) AS id,
              node_id,
              ROUND(AVG(temperature), 2) AS temperature,
              ROUND(AVG(humidity), 2) AS humidity,
              CASE
                WHEN SUM(CASE WHEN status='BERBAHAYA' THEN 1 ELSE 0 END) > 0 THEN 'BERBAHAYA'
                WHEN SUM(CASE WHEN status='WASPADA' THEN 1 ELSE 0 END) > 0 THEN 'WASPADA'
                ELSE 'AMAN'
              END AS status,
              ROUND(AVG(rssi), 0) AS rssi,
              MIN(timestamp) AS timestamp
            FROM sensor_data
            WHERE node_id=%s {time_filter}
            GROUP BY FLOOR(UNIX_TIMESTAMP(timestamp) / {interval_seconds}), node_id
            ORDER BY timestamp DESC
            LIMIT %s
        """
        async with pool.acquire() as conn:
            async with conn.cursor() as cur:
                await cur.execute(sql, (node_id, query_limit))
                rows = await cur.fetchall()
                cols = [d[0] for d in cur.description]
    else:
        # Raw data untuk 1h (node kirim setiap 10 detik → max 360 per jam)
        query_limit = max(limit, 360)
        sql = (
            f"SELECT * FROM sensor_data WHERE node_id=%s {time_filter} "
            f"ORDER BY timestamp DESC LIMIT %s"
        )
        async with pool.acquire() as conn:
            async with conn.cursor() as cur:
                await cur.execute(sql, (node_id, query_limit))
                rows = await cur.fetchall()
                cols = [d[0] for d in cur.description]

    data = [dict(zip(cols, r)) for r in rows]
    data.reverse()  # ascending untuk chart
    return {"success": True, "data": data, "count": len(data)}


@router.get("/statistics")
async def get_statistics(
    period: str = Query("24h"),
    node_id: str = Query(None),
    user=Depends(get_current_user)
):
    time_map = {
        "1h":  "DATE_SUB(NOW(), INTERVAL 1 HOUR)",
        "6h":  "DATE_SUB(NOW(), INTERVAL 6 HOUR)",
        "24h": "DATE_SUB(NOW(), INTERVAL 24 HOUR)",
        "7d":  "DATE_SUB(NOW(), INTERVAL 7 DAY)",
        "30d": "DATE_SUB(NOW(), INTERVAL 30 DAY)",
    }
    time_expr = time_map.get(period, time_map["24h"])
    where = f"WHERE timestamp >= {time_expr}"
    params = []
    if node_id:
        if not _VALID_NODE_ID.match(node_id):
            raise HTTPException(status_code=400, detail="node_id tidak valid")
        where += " AND node_id=%s"
        params.append(node_id)

    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            await cur.execute(f"""
                SELECT
                  ROUND(AVG(temperature),2) AS avg_temp,
                  ROUND(MAX(temperature),2) AS max_temp,
                  ROUND(MIN(temperature),2) AS min_temp,
                  ROUND(AVG(humidity),2)    AS avg_humidity,
                  ROUND(MAX(humidity),2)    AS max_humidity,
                  ROUND(MIN(humidity),2)    AS min_humidity,
                  COUNT(*)                  AS total_readings,
                  COUNT(CASE WHEN status='BERBAHAYA' THEN 1 END) AS danger_count,
                  COUNT(CASE WHEN status='WASPADA'   THEN 1 END) AS warning_count,
                  COUNT(CASE WHEN status='AMAN'      THEN 1 END) AS safe_count
                FROM sensor_data {where}
            """, params if params else None)
            row  = await cur.fetchone()
            cols = [d[0] for d in cur.description]
    return {"success": True, "data": dict(zip(cols, row)) if row else {}}


@router.get("/export/{node_id}")
async def export_csv(
    node_id: str,
    period: str = Query("24h"),
    user=Depends(get_current_user)
):
    """Export data sensor ke CSV — bisa diakses langsung via URL dengan token header."""
    if not _VALID_NODE_ID.match(node_id):
        raise HTTPException(status_code=400, detail="node_id tidak valid")
    time_filter = _TIME_FILTERS.get(period, _TIME_FILTERS["24h"])
    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            await cur.execute(
                f"SELECT node_id, temperature, humidity, status, rssi, timestamp "
                f"FROM sensor_data WHERE node_id=%s {time_filter} "
                f"ORDER BY timestamp ASC",
                (node_id,)
            )
            rows = await cur.fetchall()

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["node_id", "temperature_c", "humidity_pct", "status", "rssi_dbm", "timestamp_utc"])
    for row in rows:
        writer.writerow(row)
    output.seek(0)
    filename = f"susemon_{node_id}_{period}.csv"
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename={filename}"}
    )


@router.post("/data")
async def add_sensor_data(body: SensorDataIn, _=Depends(verify_gateway_key)):
    """Endpoint HTTP untuk LoRa gateway — dilindungi API key (alternatif MQTT)."""
    from app.core.config import settings
    status = "AMAN"
    if body.temperature > settings.AI_TEMP_DANGER or body.humidity > settings.AI_HUM_DANGER:
        status = "BERBAHAYA"
    elif body.temperature > settings.AI_TEMP_WARNING or body.humidity > settings.AI_HUM_WARNING:
        status = "WASPADA"

    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            if body.rssi is not None:
                await cur.execute(
                    "INSERT INTO sensor_data (node_id, temperature, humidity, status, rssi) "
                    "VALUES (%s,%s,%s,%s,%s)",
                    (body.node_id, body.temperature, body.humidity, status, body.rssi)
                )
            else:
                await cur.execute(
                    "INSERT INTO sensor_data (node_id, temperature, humidity, status) "
                    "VALUES (%s,%s,%s,%s)",
                    (body.node_id, body.temperature, body.humidity, status)
                )
            if status == "BERBAHAYA":
                await cur.execute(
                    "INSERT INTO notifications (node_id, title, message, type) "
                    "VALUES (%s,%s,%s,'critical')",
                    (body.node_id,
                     f"Suhu Kritis - Node {body.node_id}",
                     f"Suhu {body.temperature}°C, Kelembapan {body.humidity}% "
                     f"pada node {body.node_id}")
                )
    return {
        "success": True, "message": "Data berhasil disimpan",
        "data": {
            "node_id":     body.node_id,
            "temperature": body.temperature,
            "humidity":    body.humidity,
            "status":      status,
            "rssi":        body.rssi,
        }
    }


@router.get("/node-status/{node_id}")
async def get_node_status_for_device(node_id: str, _=Depends(verify_gateway_key)):
    """
    Endpoint polling status AI untuk firmware node — tidak butuh JWT.
    Node bisa HTTP GET ini setiap beberapa menit sebagai fallback.
    Response: {"node_id","status","temperature","humidity","risk_level","confidence","timestamp"}
    """
    if not _VALID_NODE_ID.match(node_id):
        raise HTTPException(status_code=400, detail="node_id tidak valid")

    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            await cur.execute(
                "SELECT status, temperature, humidity, timestamp "
                "FROM sensor_data WHERE node_id=%s ORDER BY timestamp DESC LIMIT 1",
                (node_id,)
            )
            row = await cur.fetchone()

    if not row:
        raise HTTPException(status_code=404, detail="Belum ada data untuk node ini")

    from app.services.ai_engine import analyze_node
    thresholds = await get_thresholds()
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            await cur.execute(
                "SELECT temperature, humidity, timestamp FROM sensor_data "
                "WHERE node_id=%s ORDER BY timestamp DESC LIMIT 20",
                (node_id,)
            )
            readings = [
                {"temperature": r[0], "humidity": r[1], "timestamp": r[2]}
                for r in await cur.fetchall()
            ]
    readings.reverse()

    risk_level = "LOW"
    confidence = 0
    if len(readings) >= 3:
        ai = analyze_node(readings, thresholds)
        risk_level = ai.get("risk_level", "LOW")
        confidence = ai.get("confidence", 0)

    return {
        "success": True,
        "data": {
            "node_id":     node_id,
            "status":      row[0],
            "temperature": float(row[1]),
            "humidity":    float(row[2]),
            "risk_level":  risk_level,
            "confidence":  confidence,
            "timestamp":   str(row[3]),
        }
    }


@router.get("/nodes/{node_id}")
async def get_node_detail(node_id: str, user=Depends(get_current_user)):
    if not _VALID_NODE_ID.match(node_id):
        raise HTTPException(status_code=400, detail="node_id tidak valid")
    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            await cur.execute(
                "SELECT * FROM sensor_nodes WHERE node_id=%s AND is_active=TRUE", (node_id,)
            )
            row = await cur.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="Node tidak ditemukan")
            cols = [d[0] for d in cur.description]
            node = dict(zip(cols, row))
            await cur.execute("""
                SELECT ROUND(AVG(temperature),2), ROUND(MAX(temperature),2),
                       ROUND(MIN(temperature),2), COUNT(*),
                       COUNT(CASE WHEN status='BERBAHAYA' THEN 1 END)
                FROM sensor_data
                WHERE node_id=%s AND timestamp >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
            """, (node_id,))
            stats = await cur.fetchone()
    node["stats_24h"] = {
        "avg_temp":    stats[0], "max_temp": stats[1],
        "min_temp":    stats[2], "total":    stats[3],
        "danger_count": stats[4],
    }
    return {"success": True, "data": node}


@router.post("/nodes")
async def create_node(body: SensorNodeCreate, user=Depends(require_pic_or_admin)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            try:
                await cur.execute(
                    "INSERT INTO sensor_nodes (node_id, node_name, location, is_active) "
                    "VALUES (%s,%s,%s,%s)",
                    (body.node_id, body.node_name, body.location, body.is_active)
                )
                new_id = cur.lastrowid
            except Exception:
                raise HTTPException(
                    status_code=409,
                    detail=f"node_id '{body.node_id}' sudah terdaftar"
                )
    return {"success": True, "message": "Perangkat berhasil didaftarkan", "data": {"id": new_id}}


@router.put("/nodes/{node_id}")
async def update_node(node_id: str, body: SensorNodeUpdate, user=Depends(require_pic_or_admin)):
    updates = {}
    if body.node_name is not None: updates["node_name"] = body.node_name
    if body.location  is not None: updates["location"]  = body.location
    if body.is_active is not None: updates["is_active"] = body.is_active

    if not updates:
        raise HTTPException(status_code=400, detail="Tidak ada data yang diupdate")

    set_clause = ", ".join(f"{k}=%s" for k in updates)
    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            await cur.execute(
                f"UPDATE sensor_nodes SET {set_clause} WHERE node_id=%s",
                (*updates.values(), node_id)
            )
            if cur.rowcount == 0:
                raise HTTPException(status_code=404, detail="Perangkat tidak ditemukan")
    return {"success": True, "message": "Perangkat berhasil diupdate"}


@router.delete("/nodes/{node_id}")
async def delete_node(node_id: str, user=Depends(require_pic_or_admin)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            await cur.execute("DELETE FROM sensor_nodes WHERE node_id=%s", (node_id,))
            if cur.rowcount == 0:
                raise HTTPException(status_code=404, detail="Perangkat tidak ditemukan")
    return {"success": True, "message": "Perangkat berhasil dihapus"}


@router.get("/thresholds")
async def get_thresholds_endpoint(user=Depends(get_current_user)):
    thresholds = await get_thresholds()
    return {"success": True, "data": thresholds}


@router.put("/thresholds")
async def update_thresholds_endpoint(
    body: dict = Body(...),
    user=Depends(get_current_user)
):
    """
    Update AI thresholds. Sinkron dengan settings_page_new.dart slider.
    Semua 4 nilai bisa diupdate sekaligus atau sebagian.
    """
    current = await get_thresholds()
    temp_warning = float(body.get("temp_warning", current.get("temp_warning", 35.0)))
    temp_danger  = float(body.get("temp_danger",  current.get("temp_danger",  40.0)))
    hum_warning  = float(body.get("hum_warning",  current.get("hum_warning",  80.0)))
    hum_danger   = float(body.get("hum_danger",   current.get("hum_danger",   85.0)))

    await update_thresholds(temp_warning, temp_danger, hum_warning, hum_danger)
    return {"success": True, "message": "Thresholds updated successfully"}
