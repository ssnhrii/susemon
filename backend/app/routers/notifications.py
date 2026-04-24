from fastapi import APIRouter, Depends, Query
from app.core.database import get_pool
from app.core.security import get_current_user

router = APIRouter(prefix="/api/notifications", tags=["notifications"])


@router.get("")
async def get_notifications(
    limit: int = Query(20, ge=1, le=100),
    unread_only: bool = Query(False),
    user=Depends(get_current_user)
):
    where = "WHERE n.is_read=FALSE" if unread_only else ""
    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            await cur.execute(f"""
                SELECT n.*, sn.node_name, sn.location
                FROM notifications n
                LEFT JOIN sensor_nodes sn ON n.node_id=sn.node_id
                {where}
                ORDER BY n.created_at DESC LIMIT %s
            """, (limit,))
            rows = await cur.fetchall()
            cols = [d[0] for d in cur.description]
    return {"success": True, "data": [dict(zip(cols, r)) for r in rows]}


@router.get("/unread-count")
async def unread_count(user=Depends(get_current_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            await cur.execute("SELECT COUNT(*) FROM notifications WHERE is_read=FALSE")
            count = (await cur.fetchone())[0]
    return {"success": True, "data": {"count": count}}


@router.put("/{notif_id}/read")
async def mark_read(notif_id: int, user=Depends(get_current_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            await cur.execute("UPDATE notifications SET is_read=TRUE WHERE id=%s", (notif_id,))
    return {"success": True, "message": "Notifikasi ditandai sebagai dibaca"}
