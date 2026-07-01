"""
Database — aiomysql async connection pool
"""
import aiomysql
import warnings
warnings.filterwarnings("ignore", module="aiomysql")
from app.core.config import settings
import logging

logger = logging.getLogger("susemon")
_pool: aiomysql.Pool = None


async def get_pool() -> aiomysql.Pool:
    global _pool
    if _pool is None or _pool._closed:
        _pool = await aiomysql.create_pool(
            host=settings.DB_HOST,
            port=settings.DB_PORT,
            user=settings.DB_USER,
            password=settings.DB_PASSWORD,
            db=settings.DB_NAME,
            autocommit=True,
            minsize=2,
            maxsize=10,
            charset="utf8mb4",
            connect_timeout=10,
        )
        logger.info("Database pool created")
    return _pool


async def close_pool():
    global _pool
    if _pool:
        _pool.close()
        await _pool.wait_closed()
        _pool = None


async def init_db():
    """Buat tabel dan seed data awal"""
    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            # users — dengan role dan is_active
            await cur.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    id          INT PRIMARY KEY AUTO_INCREMENT,
                    ip_address  VARCHAR(50)  UNIQUE NOT NULL,
                    access_code VARCHAR(255) NOT NULL,
                    name        VARCHAR(100),
                    role        ENUM('admin','pic') DEFAULT 'pic',
                    is_active   BOOLEAN DEFAULT TRUE,
                    last_ip     VARCHAR(50),
                    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    last_login  TIMESTAMP NULL
                )
            """)
            # Tambah kolom baru jika belum ada (migrasi aman)
            for col_sql in [
                "ALTER TABLE users ADD COLUMN role ENUM('admin','pic') DEFAULT 'pic'",
                "ALTER TABLE users ADD COLUMN is_active BOOLEAN DEFAULT TRUE",
                "ALTER TABLE users ADD COLUMN last_ip VARCHAR(50)",
            ]:
                try:
                    await cur.execute(col_sql)
                except Exception:
                    pass  # kolom sudah ada

            # sensor_nodes
            await cur.execute("""
                CREATE TABLE IF NOT EXISTS sensor_nodes (
                    id         INT PRIMARY KEY AUTO_INCREMENT,
                    node_id    VARCHAR(20)  UNIQUE NOT NULL,
                    node_name  VARCHAR(100) NOT NULL,
                    location   VARCHAR(200) NOT NULL,
                    is_active  BOOLEAN DEFAULT TRUE,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
                )
            """)

            # sensor_data
            await cur.execute("""
                CREATE TABLE IF NOT EXISTS sensor_data (
                    id          INT PRIMARY KEY AUTO_INCREMENT,
                    node_id     VARCHAR(20)  NOT NULL,
                    temperature DECIMAL(5,2) NOT NULL,
                    humidity    DECIMAL(5,2) NOT NULL,
                    status      ENUM('AMAN','WASPADA','BERBAHAYA') NOT NULL,
                    rssi        SMALLINT DEFAULT NULL,
                    timestamp   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (node_id) REFERENCES sensor_nodes(node_id) ON DELETE CASCADE,
                    INDEX idx_node_ts (node_id, timestamp),
                    INDEX idx_ts      (timestamp),
                    INDEX idx_status  (status)
                )
            """)
            # Tambah kolom rssi jika belum ada
            try:
                await cur.execute("ALTER TABLE sensor_data ADD COLUMN rssi SMALLINT DEFAULT NULL")
            except Exception:
                pass

            # notifications
            await cur.execute("""
                CREATE TABLE IF NOT EXISTS notifications (
                    id         INT PRIMARY KEY AUTO_INCREMENT,
                    node_id    VARCHAR(20),
                    title      VARCHAR(200) NOT NULL,
                    message    TEXT         NOT NULL,
                    type       ENUM('critical','warning','success','info') NOT NULL,
                    is_read    BOOLEAN DEFAULT FALSE,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (node_id) REFERENCES sensor_nodes(node_id) ON DELETE SET NULL,
                    INDEX idx_created  (created_at),
                    INDEX idx_is_read  (is_read)
                )
            """)

            # ai_predictions
            await cur.execute("""
                CREATE TABLE IF NOT EXISTS ai_predictions (
                    id               INT PRIMARY KEY AUTO_INCREMENT,
                    node_id          VARCHAR(20)  NOT NULL,
                    prediction_type  VARCHAR(50)  NOT NULL,
                    confidence       DECIMAL(5,2) NOT NULL,
                    predicted_value  DECIMAL(5,2),
                    risk_level       ENUM('LOW','MEDIUM','HIGH') DEFAULT 'LOW',
                    prediction_time  TIMESTAMP    NOT NULL,
                    created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (node_id) REFERENCES sensor_nodes(node_id) ON DELETE CASCADE,
                    INDEX idx_node_time (node_id, prediction_time)
                )
            """)
            try:
                await cur.execute("ALTER TABLE ai_predictions ADD COLUMN risk_level ENUM('LOW','MEDIUM','HIGH') DEFAULT 'LOW'")
            except Exception:
                pass

            # system_settings
            await cur.execute("""
                CREATE TABLE IF NOT EXISTS system_settings (
                    setting_key   VARCHAR(100) PRIMARY KEY,
                    setting_value VARCHAR(255) NOT NULL,
                    updated_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
                )
            """)
            # Seed system_settings jika kosong
            await cur.execute("SELECT COUNT(*) FROM system_settings")
            settings_count = (await cur.fetchone())[0]
            if settings_count == 0:
                await cur.execute("""
                    INSERT IGNORE INTO system_settings (setting_key, setting_value) VALUES
                    ('temp_warning', '30'),
                    ('temp_danger', '40'),
                    ('hum_warning', '80'),
                    ('hum_danger', '85'),
                    ('mqtt_broker', 'broker.hivemq.com'),
                    ('mqtt_port', '1883'),
                    ('mqtt_user', ''),
                    ('mqtt_pass', ''),
                    ('mqtt_topic', 'susemon/sensor/data/pbl_412'),
                    ('mqtt_downlink_topic', 'susemon/sensor/ai_result/pbl_412'),
                    ('lora_freq', '915000000'),
                    ('lora_datr', 'SF7BW125'),
                    ('lora_codr', '4/5'),
                    ('gateway_ip', '10.130.1.1'),
                    ('gateway_api_key', 'gw-Xk9mP2nQ8rL5vT3wY7uJ4hF6cB1eA0sD')
                """)

            # Selalu sinkronkan konfigurasi MQTT dari .env ke DB saat startup agar tidak memakai data lama
            from app.core.config import settings as cfg
            mqtt_settings = {
                'mqtt_broker': cfg.MQTT_BROKER,
                'mqtt_port': str(cfg.MQTT_PORT),
                'mqtt_user': cfg.MQTT_USER,
                'mqtt_pass': cfg.MQTT_PASS,
                'mqtt_topic': cfg.MQTT_TOPIC,
                'mqtt_downlink_topic': cfg.MQTT_DOWNLINK_TOPIC
            }
            for key, val in mqtt_settings.items():
                await cur.execute("""
                    INSERT INTO system_settings (setting_key, setting_value) VALUES (%s, %s)
                    ON DUPLICATE KEY UPDATE setting_value = %s
                """, (key, str(val), str(val)))

            # Verifikasi dan buat index jika belum ada
            async def ensure_index(table_name: str, index_name: str, columns: str):
                try:
                    await cur.execute(
                        "SELECT 1 FROM INFORMATION_SCHEMA.STATISTICS "
                        "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = %s AND INDEX_NAME = %s "
                        "LIMIT 1",
                        (table_name, index_name)
                    )
                    exists = await cur.fetchone()
                    if not exists:
                        await cur.execute(f"ALTER TABLE {table_name} ADD INDEX {index_name} ({columns})")
                        logger.info(f"Created index {index_name} on table {table_name}")
                except Exception as e:
                    logger.error(f"Error ensuring index {index_name} on table {table_name}: {e}")

            await ensure_index("sensor_data", "idx_node_ts", "node_id, timestamp")
            await ensure_index("sensor_data", "idx_ts", "timestamp")
            await ensure_index("sensor_data", "idx_status", "status")
            await ensure_index("notifications", "idx_created", "created_at")
            await ensure_index("notifications", "idx_is_read", "is_read")
            await ensure_index("notifications", "idx_node_created", "node_id, created_at")
            await ensure_index("ai_predictions", "idx_node_time", "node_id, prediction_time")

            # Seed users — password di-hash dengan bcrypt
            import bcrypt as _bcrypt
            _hash_admin   = _bcrypt.hashpw(b"ADMIN123"[:72],    _bcrypt.gensalt(rounds=12)).decode()
            _hash_network = _bcrypt.hashpw(b"SUSEMON2026"[:72], _bcrypt.gensalt(rounds=12)).decode()

            await cur.execute("""
                INSERT IGNORE INTO users (ip_address, access_code, name, role) VALUES
                ('127.0.0.1', %s, 'Admin Local',   'admin'),
                ('0.0.0.0',   %s, 'Admin Network', 'admin')
            """, (_hash_admin, _hash_network))
            # Update role jika sudah ada tapi belum punya role
            await cur.execute("""
                UPDATE users SET role='admin'
                WHERE ip_address IN ('127.0.0.1','0.0.0.0') AND (role IS NULL OR role='pic')
            """)

            # Seed node utama saja jika belum ada node sama sekali
            await cur.execute("SELECT COUNT(*) FROM sensor_nodes")
            node_count = (await cur.fetchone())[0]
            if node_count == 0:
                await cur.execute("""
                    INSERT IGNORE INTO sensor_nodes (node_id, node_name, location) VALUES
                    ('TA11','Node Sensor TA11','Rack Server Utama')
                """)

    logger.info("Database initialized")


async def cleanup_old_data(retention_days: int = 90):
    """Hapus data sensor lebih dari retention_days hari"""
    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            await cur.execute(
                "DELETE FROM sensor_data WHERE timestamp < DATE_SUB(NOW(), INTERVAL %s DAY)",
                (retention_days,)
            )
            deleted_sensor = cur.rowcount
            await cur.execute(
                "DELETE FROM ai_predictions WHERE created_at < DATE_SUB(NOW(), INTERVAL %s DAY)",
                (retention_days,)
            )
            deleted_ai = cur.rowcount
            await cur.execute(
                "DELETE FROM notifications WHERE created_at < DATE_SUB(NOW(), INTERVAL %s DAY) AND is_read=TRUE",
                (retention_days,)
            )
            deleted_notif = cur.rowcount
    logger.info(
        f"Retention cleanup: sensor={deleted_sensor} ai={deleted_ai} notif={deleted_notif} rows deleted"
    )


_SETTINGS_CACHE = {}

async def get_system_settings() -> dict:
    global _SETTINGS_CACHE
    if _SETTINGS_CACHE:
        return _SETTINGS_CACHE

    try:
        pool = await get_pool()
        async with pool.acquire() as conn:
            async with conn.cursor() as cur:
                await cur.execute("SELECT setting_key, setting_value FROM system_settings")
                rows = await cur.fetchall()
                if rows:
                    _SETTINGS_CACHE = {r[0]: r[1] for r in rows}
                    return _SETTINGS_CACHE
    except Exception as e:
        logger.error(f"Error loading system settings from DB: {e}")

    # Fallback to config settings
    from app.core.config import settings as cfg
    return {
        "temp_warning": str(cfg.AI_TEMP_WARNING),
        "temp_danger": str(cfg.AI_TEMP_DANGER),
        "hum_warning": str(cfg.AI_HUM_WARNING),
        "hum_danger": str(cfg.AI_HUM_DANGER),
        "mqtt_broker": cfg.MQTT_BROKER,
        "mqtt_port": str(cfg.MQTT_PORT),
        "mqtt_user": cfg.MQTT_USER,
        "mqtt_pass": cfg.MQTT_PASS,
        "mqtt_topic": cfg.MQTT_TOPIC,
        "mqtt_downlink_topic": cfg.MQTT_DOWNLINK_TOPIC,
        "lora_freq": "915000000",
        "lora_datr": "SF7BW125",
        "lora_codr": "4/5",
        "gateway_ip": cfg.SERVER_IP,
        "gateway_api_key": cfg.GATEWAY_API_KEY
    }

async def get_thresholds():
    s = await get_system_settings()
    try:
        return {
            "temp_warning": float(s.get("temp_warning", 30.0)),
            "temp_danger": float(s.get("temp_danger", 40.0)),
            "hum_warning": float(s.get("hum_warning", 80.0)),
            "hum_danger": float(s.get("hum_danger", 85.0)),
        }
    except Exception:
        return {
            "temp_warning": 30.0,
            "temp_danger": 40.0,
            "hum_warning": 80.0,
            "hum_danger": 85.0,
        }

async def update_system_settings_dict(settings_dict: dict):
    global _SETTINGS_CACHE
    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            for key, val in settings_dict.items():
                await cur.execute(
                    "INSERT INTO system_settings (setting_key, setting_value) VALUES (%s, %s) "
                    "ON DUPLICATE KEY UPDATE setting_value = %s",
                    (key, str(val), str(val))
                )
    _SETTINGS_CACHE.clear()
    logger.info(f"System settings updated in DB: {list(settings_dict.keys())}")

async def update_thresholds(temp_warning: float, temp_danger: float, hum_warning: float, hum_danger: float):
    await update_system_settings_dict({
        "temp_warning": temp_warning,
        "temp_danger": temp_danger,
        "hum_warning": hum_warning,
        "hum_danger": hum_danger
    })
