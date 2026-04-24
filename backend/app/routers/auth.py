from fastapi import APIRouter, HTTPException, Depends
from app.core.database import get_pool
from app.core.security import create_token, get_current_user
from app.models.schemas import LoginRequest

router = APIRouter(prefix="/api/auth", tags=["auth"])


@router.post("/login")
async def login(body: LoginRequest):
    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            await cur.execute(
                "SELECT * FROM users WHERE ip_address=%s AND access_code=%s",
                (body.ip_address, body.access_code)
            )
            user = await cur.fetchone()
            if not user:
                raise HTTPException(status_code=401, detail="IP Address atau Access Code tidak valid")

            await cur.execute("UPDATE users SET last_login=NOW() WHERE id=%s", (user[0],))

    token = create_token({"id": user[0], "ip_address": user[1]})
    return {
        "success": True,
        "message": "Login berhasil",
        "data": {
            "token": token,
            "user": {"id": user[0], "ip_address": user[1], "name": user[3]}
        }
    }


@router.get("/verify")
async def verify(user=Depends(get_current_user)):
    return {"success": True, "message": "Token valid", "data": {"user": user}}
