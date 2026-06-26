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
    if _pool is None:
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
                    ('temp_warning', '35'),
                    ('temp_danger', '40'),
                    ('hum_warning', '80'),
                    ('hum_danger', '85')
                """)

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


_THRESHOLDS_CACHE = {}

async def get_thresholds():
    global _THRESHOLDS_CACHE
    if _THRESHOLDS_CACHE:
        return _THRESHOLDS_CACHE

    try:
        pool = await get_pool()
        async with pool.acquire() as conn:
            async with conn.cursor() as cur:
                await cur.execute("SELECT setting_key, setting_value FROM system_settings")
                rows = await cur.fetchall()
                if rows:
                    _THRESHOLDS_CACHE = {r[0]: float(r[1]) for r in rows}
                    return _THRESHOLDS_CACHE
    except Exception as e:
        logger.error(f"Error loading thresholds from DB: {e}")

    # Fallback to config.settings if DB fails/is not initialized
    from app.core.config import settings as cfg
    return {
        "temp_warning": cfg.AI_TEMP_WARNING,
        "temp_danger": cfg.AI_TEMP_DANGER,
        "hum_warning": cfg.AI_HUM_WARNING,
        "hum_danger": cfg.AI_HUM_DANGER,
    }

async def update_thresholds(temp_warning: float, temp_danger: float, hum_warning: float, hum_danger: float):
    global _THRESHOLDS_CACHE
    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.cursor() as cur:
            for key, val in [
                ("temp_warning", temp_warning),
                ("temp_danger", temp_danger),
                ("hum_warning", hum_warning),
                ("hum_danger", hum_danger)
            ]:
                await cur.execute(
                    "INSERT INTO system_settings (setting_key, setting_value) VALUES (%s, %s) "
                    "ON DUPLICATE KEY UPDATE setting_value = %s",
                    (key, str(val), str(val))
                )
    _THRESHOLDS_CACHE.clear()
    logger.info(f"Thresholds updated in DB: temp_w={temp_warning}, temp_d={temp_danger}, hum_w={hum_warning}, hum_d={hum_danger}")
