from datetime import datetime, timedelta
from jose import JWTError, jwt
from fastapi import HTTPException, Security, Request, Header
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.core.config import settings

bearer = HTTPBearer()


def create_token(data: dict) -> str:
    payload = data.copy()
    payload["exp"] = datetime.utcnow() + timedelta(hours=settings.JWT_EXPIRE_HOURS)
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)


def decode_token(token: str) -> dict:
    try:
        return jwt.decode(token, settings.JWT_SECRET, algorithms=[settings.JWT_ALGORITHM])
    except JWTError:
        raise HTTPException(status_code=401, detail="Token tidak valid atau sudah expired")


async def get_current_user(credentials: HTTPAuthorizationCredentials = Security(bearer)):
    return decode_token(credentials.credentials)


def verify_gateway_key(x_api_key: str = Header(...)):
    """Dependency untuk endpoint gateway — validasi API key"""
    if x_api_key != settings.GATEWAY_API_KEY:
        raise HTTPException(status_code=403, detail="API key tidak valid")
    return x_api_key
