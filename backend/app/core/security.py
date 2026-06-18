"""
Security — JWT auth + bcrypt + role-based access control + brute force protection
Roles: admin (full access), pic (device management + reports)
"""
import time
import secrets
import bcrypt
from datetime import datetime, timedelta, timezone
from collections import defaultdict
from jose import JWTError, jwt
from fastapi import HTTPException, Security, Header, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.core.config import settings

bearer = HTTPBearer()


# ── Bcrypt — pakai library bcrypt langsung, bypass passlib ───────────────────

def hash_password(plain: str) -> str:
    """Hash access code dengan bcrypt"""
    return bcrypt.hashpw(plain.encode("utf-8"), bcrypt.gensalt(rounds=12)).decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    """Verifikasi access code terhadap hash bcrypt"""
    try:
        return bcrypt.checkpw(plain.encode("utf-8"), hashed.encode("utf-8"))
    except Exception:
        return False


def is_hashed(value: str) -> bool:
    """Cek apakah value sudah di-hash bcrypt"""
    return value.startswith("$2b$") or value.startswith("$2a$")


# ── Brute Force Protection ────────────────────────────────────────────────────
# {ip: {"count": int, "locked_until": float, "last_attempt": float}}
_login_attempts: dict = defaultdict(lambda: {"count": 0, "locked_until": 0.0})

MAX_ATTEMPTS   = 5       # max gagal sebelum lockout
LOCKOUT_SECS   = 300     # 5 menit lockout
ATTEMPT_WINDOW = 600     # reset counter setelah 10 menit tidak ada percobaan


def check_brute_force(ip: str) -> None:
    """Raise 429 jika IP sedang dalam lockout"""
    now = time.time()
    state = _login_attempts[ip]

    # Cek apakah masih dalam lockout
    if state["locked_until"] > now:
        remaining = int(state["locked_until"] - now)
        raise HTTPException(
            status_code=429,
            detail=f"Terlalu banyak percobaan login. Coba lagi dalam {remaining} detik."
        )

    # Reset counter jika sudah lama tidak ada percobaan
    if state.get("last_attempt", 0) > 0:
        if now - state["last_attempt"] > ATTEMPT_WINDOW:
            state["count"] = 0
            state["locked_until"] = 0.0


def record_failed_login(ip: str) -> None:
    """Catat percobaan login gagal, lockout jika melebihi batas"""
    now = time.time()
    state = _login_attempts[ip]
    state["count"] += 1
    state["last_attempt"] = now

    if state["count"] >= MAX_ATTEMPTS:
        state["locked_until"] = now + LOCKOUT_SECS
        state["count"] = 0
        raise HTTPException(
            status_code=429,
            detail=f"Akun dikunci selama {LOCKOUT_SECS // 60} menit karena terlalu banyak percobaan gagal."
        )


def record_success_login(ip: str) -> None:
    """Reset counter setelah login berhasil"""
    _login_attempts[ip] = {"count": 0, "locked_until": 0.0, "last_attempt": 0.0}


# ── JWT ───────────────────────────────────────────────────────────────────────

def create_token(data: dict) -> str:
    payload = data.copy()
    payload["exp"] = datetime.now(timezone.utc) + timedelta(hours=settings.JWT_EXPIRE_HOURS)
    payload["iat"] = datetime.now(timezone.utc)
    payload["jti"] = secrets.token_hex(8)  # unique token ID
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)


def decode_token(token: str) -> dict:
    try:
        return jwt.decode(token, settings.JWT_SECRET, algorithms=[settings.JWT_ALGORITHM])
    except JWTError:
        raise HTTPException(status_code=401, detail="Token tidak valid atau sudah expired")


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Security(bearer)
) -> dict:
    return decode_token(credentials.credentials)


async def require_admin(user: dict = Depends(get_current_user)) -> dict:
    """Dependency — hanya admin yang bisa akses endpoint ini"""
    if user.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Akses ditolak: diperlukan role admin")
    return user


async def require_pic_or_admin(user: dict = Depends(get_current_user)) -> dict:
    """Dependency — PIC dan Admin bisa akses endpoint ini (misal: manajemen perangkat)"""
    if user.get("role") not in ("admin", "pic"):
        raise HTTPException(status_code=403, detail="Akses ditolak: diperlukan role Admin atau PIC")
    return user


def verify_gateway_key(x_api_key: str = Header(...)):
    """Dependency untuk endpoint gateway — validasi API key dengan timing-safe compare"""
    if not secrets.compare_digest(x_api_key, settings.GATEWAY_API_KEY):
        raise HTTPException(status_code=403, detail="API key tidak valid")
    return x_api_key
