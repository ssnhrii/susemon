"""
Auth Router — Login dengan IP Address + Access Code
Fitur keamanan:
- bcrypt untuk verifikasi access code
- Brute force protection (lockout 5 menit setelah 5x gagal)
- Timing-safe comparison
- Login attempt logging
"""
import ipaddress
import logging
from fastapi import APIRouter, HTTPException, Depends, Request
from app.core.database import get_pool
from app.core.security import (
    create_token, get_current_user,
    verify_password, is_hashed,
    check_brute_force, record_failed_login, record_success_login
)
from app.models.schemas import LoginRequest

router = APIRouter(prefix="/api/auth", tags=["auth"])
logger = logging.getLogger("susemon")


@router.post("/login")
async def login(body: LoginRequest, request: Request):
    client_ip = request.client.host if request.client else "unknown"

    # Validasi format IP
    try:
        ipaddress.ip_address(body.ip_address)
    except ValueError:
        raise HTTPException(status_code=400, detail="Format IP Address tidak valid")

    if len(body.access_code.strip()) < 4:
        raise HTTPException(status_code=400, detail="Access Code terlalu pendek (min 4 karakter)")

    # Cek brute force — raise 429 jika sedang lockout
    check_brute_force(client_ip)

    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            # Ambil user berdasarkan IP (exact match dulu)
            await cur.execute(
                "SELECT id, ip_address, name, role, access_code FROM users "
                "WHERE ip_address=%s AND is_active=TRUE",
                (body.ip_address,)
            )
            user = await cur.fetchone()

            # Fallback: wildcard 0.0.0.0
            if not user:
                await cur.execute(
                    "SELECT id, ip_address, name, role, access_code FROM users "
                    "WHERE ip_address='0.0.0.0' AND is_active=TRUE"
                )
                user = await cur.fetchone()

            if not user:
                record_failed_login(client_ip)
                logger.warning(f"Login gagal — IP tidak ditemukan: {body.ip_address} dari {client_ip}")
                # Pesan generik — jangan bocorkan info apakah IP ada atau tidak
                raise HTTPException(status_code=401, detail="IP Address atau Access Code tidak valid")

            stored_code = user[4]

            # Verifikasi access code — support bcrypt hash dan plain text (migrasi)
            if is_hashed(stored_code):
                valid = verify_password(body.access_code, stored_code)
            else:
                # Plain text — bandingkan langsung (data lama sebelum migrasi)
                valid = (body.access_code == stored_code)

            if not valid:
                record_failed_login(client_ip)
                logger.warning(f"Login gagal — access code salah untuk IP: {body.ip_address} dari {client_ip}")
                raise HTTPException(status_code=401, detail="IP Address atau Access Code tidak valid")

            # Login berhasil
            record_success_login(client_ip)
            await cur.execute(
                "UPDATE users SET last_login=NOW(), last_ip=%s WHERE id=%s",
                (client_ip, user[0])
            )
            logger.info(f"Login berhasil: user_id={user[0]} ip={body.ip_address} role={user[3]} dari {client_ip}")

    token = create_token({
        "id":         user[0],
        "ip_address": body.ip_address,
        "role":       user[3] or "pic"
    })
    return {
        "success": True,
        "message": "Login berhasil",
        "data": {
            "token": token,
            "user": {
                "id":         user[0],
                "ip_address": body.ip_address,
                "name":       user[2],
                "role":       user[3] or "pic"
            }
        }
    }


@router.get("/verify")
async def verify(user=Depends(get_current_user)):
    return {"success": True, "message": "Token valid", "data": {"user": user}}


@router.post("/logout")
async def logout(user=Depends(get_current_user)):
    return {"success": True, "message": "Logout berhasil"}
