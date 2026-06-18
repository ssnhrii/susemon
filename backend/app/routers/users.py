"""
Users Router — Manajemen user (admin only)
Access code di-hash dengan bcrypt sebelum disimpan ke database
"""
import ipaddress
import logging
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel, field_validator
from typing import Optional
from app.core.database import get_pool
from app.core.security import get_current_user, require_admin, hash_password

router = APIRouter(prefix="/api/users", tags=["users"])
logger = logging.getLogger("susemon")


class UserCreate(BaseModel):
    ip_address: str
    access_code: str
    name: str
    role: str = "pic"

    @field_validator("ip_address")
    @classmethod
    def validate_ip(cls, v):
        v = v.strip()
        if v != "0.0.0.0":
            try:
                ipaddress.ip_address(v)
            except ValueError:
                raise ValueError("Format IP Address tidak valid")
        return v

    @field_validator("access_code")
    @classmethod
    def validate_code(cls, v):
        if len(v.strip()) < 6:
            raise ValueError("Access code minimal 6 karakter")
        if len(v.strip()) > 64:
            raise ValueError("Access code maksimal 64 karakter")
        return v.strip()

    @field_validator("name")
    @classmethod
    def validate_name(cls, v):
        v = v.strip()
        if len(v) < 2:
            raise ValueError("Nama minimal 2 karakter")
        if len(v) > 100:
            raise ValueError("Nama maksimal 100 karakter")
        return v

    @field_validator("role")
    @classmethod
    def validate_role(cls, v):
        if v not in ("admin", "pic"):
            raise ValueError("Role harus 'admin' atau 'pic'")
        return v


class UserUpdate(BaseModel):
    name: Optional[str] = None
    access_code: Optional[str] = None
    role: Optional[str] = None
    is_active: Optional[bool] = None


@router.get("")
async def get_users(user=Depends(require_admin)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            await cur.execute(
                "SELECT id, ip_address, name, role, is_active, created_at, last_login, last_ip "
                "FROM users ORDER BY created_at DESC"
            )
            rows = await cur.fetchall()
            cols = [d[0] for d in cur.description]
    return {"success": True, "data": [dict(zip(cols, r)) for r in rows]}


@router.post("")
async def create_user(body: UserCreate, user=Depends(require_admin)):
    # Hash access code sebelum simpan
    hashed_code = hash_password(body.access_code)

    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            try:
                await cur.execute(
                    "INSERT INTO users (ip_address, access_code, name, role) VALUES (%s,%s,%s,%s)",
                    (body.ip_address, hashed_code, body.name, body.role)
                )
                new_id = cur.lastrowid
            except Exception:
                raise HTTPException(status_code=409, detail="IP Address sudah terdaftar")

    logger.info(f"User baru dibuat: id={new_id} ip={body.ip_address} role={body.role} oleh admin_id={user['id']}")
    return {"success": True, "message": "User berhasil dibuat", "data": {"id": new_id}}


@router.put("/{user_id}")
async def update_user(user_id: int, body: UserUpdate, user=Depends(require_admin)):
    updates = {}

    if body.name is not None:
        name = body.name.strip()
        if len(name) < 2:
            raise HTTPException(status_code=400, detail="Nama minimal 2 karakter")
        updates["name"] = name

    if body.access_code is not None:
        code = body.access_code.strip()
        if len(code) < 6:
            raise HTTPException(status_code=400, detail="Access code minimal 6 karakter")
        # Hash access code baru
        updates["access_code"] = hash_password(code)

    if body.role is not None:
        if body.role not in ("admin", "pic"):
            raise HTTPException(status_code=400, detail="Role tidak valid")
        updates["role"] = body.role

    if body.is_active is not None:
        updates["is_active"] = body.is_active

    if not updates:
        raise HTTPException(status_code=400, detail="Tidak ada data yang diupdate")

    set_clause = ", ".join(f"{k}=%s" for k in updates)
    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            await cur.execute(
                f"UPDATE users SET {set_clause} WHERE id=%s",
                (*updates.values(), user_id)
            )
            if cur.rowcount == 0:
                raise HTTPException(status_code=404, detail="User tidak ditemukan")

    logger.info(f"User diupdate: id={user_id} fields={list(updates.keys())} oleh admin_id={user['id']}")
    return {"success": True, "message": "User berhasil diupdate"}


@router.delete("/{user_id}")
async def delete_user(user_id: int, user=Depends(require_admin)):
    if user_id == user.get("id"):
        raise HTTPException(status_code=400, detail="Tidak bisa menghapus akun sendiri")

    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            await cur.execute("DELETE FROM users WHERE id=%s", (user_id,))
            if cur.rowcount == 0:
                raise HTTPException(status_code=404, detail="User tidak ditemukan")

    logger.info(f"User dihapus: id={user_id} oleh admin_id={user['id']}")
    return {"success": True, "message": "User berhasil dihapus"}


@router.get("/me")
async def get_me(user=Depends(get_current_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            await cur.execute(
                "SELECT id, ip_address, name, role, created_at, last_login FROM users WHERE id=%s",
                (user["id"],)
            )
            row = await cur.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="User tidak ditemukan")
            cols = [d[0] for d in cur.description]
    return {"success": True, "data": dict(zip(cols, row))}
