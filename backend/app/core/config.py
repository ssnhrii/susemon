import os
from dotenv import load_dotenv

load_dotenv()

class Settings:
    # Server
    PORT: int          = int(os.getenv("PORT", 3000))
    WS_PORT: int       = int(os.getenv("WS_PORT", 3001))
    NODE_ENV: str      = os.getenv("NODE_ENV", "development")

    # Database
    DB_HOST: str       = os.getenv("DB_HOST", "localhost")
    DB_PORT: int       = int(os.getenv("DB_PORT", 3306))
    DB_USER: str       = os.getenv("DB_USER", "root")
    DB_PASSWORD: str   = os.getenv("DB_PASSWORD", "")
    DB_NAME: str       = os.getenv("DB_NAME", "susemon_db")

    # JWT
    JWT_SECRET: str    = os.getenv("JWT_SECRET", "susemon_secret_key_2026_pbl_trpl412")
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRE_HOURS: int = 24

    # CORS
    CORS_ORIGINS: list = os.getenv("CORS_ORIGIN", "*").split(",")

    # AI Thresholds
    AI_TEMP_WARNING: float  = float(os.getenv("AI_THRESHOLD_TEMP_WARNING", 35))
    AI_TEMP_DANGER: float   = float(os.getenv("AI_THRESHOLD_TEMP", 40))
    AI_HUM_WARNING: float   = float(os.getenv("AI_THRESHOLD_HUM_WARNING", 70))
    AI_HUM_DANGER: float    = float(os.getenv("AI_THRESHOLD_HUMIDITY", 80))

    # MQTT
    MQTT_BROKER: str     = os.getenv("MQTT_BROKER", "localhost")
    MQTT_PORT: int       = int(os.getenv("MQTT_PORT", 1883))
    MQTT_TOPIC: str      = os.getenv("MQTT_TOPIC", "sensor/data")
    MQTT_CLIENT_ID: str  = os.getenv("MQTT_CLIENT_ID", "susemon-fastapi")

settings = Settings()
