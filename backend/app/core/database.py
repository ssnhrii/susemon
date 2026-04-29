import aiomysql
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
            # users
            await cur.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    id INT PRIMARY KEY AUTO_INCREMENT,
                    ip_address VARCHAR(50) UNIQUE NOT NULL,
                    access_code VARCHAR(255) NOT NULL,
                    name VARCHAR(100),
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    last_login TIMESTAMP NULL
                )
            """)
            # sensor_nodes
            await cur.execute("""
                CREATE TABLE IF NOT EXISTS sensor_nodes (
                    id INT PRIMARY KEY AUTO_INCREMENT,
                    node_id VARCHAR(10) UNIQUE NOT NULL,
                    node_name VARCHAR(100) NOT NULL,
                    location VARCHAR(200) NOT NULL,
                    is_active BOOLEAN DEFAULT TRUE,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
                )
            """)
            # sensor_data
            await cur.execute("""
                CREATE TABLE IF NOT EXISTS sensor_data (
                    id INT PRIMARY KEY AUTO_INCREMENT,
                    node_id VARCHAR(10) NOT NULL,
                    temperature DECIMAL(5,2) NOT NULL,
                    humidity DECIMAL(5,2) NOT NULL,
                    status ENUM('AMAN','WASPADA','BERBAHAYA') NOT NULL,
                    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (node_id) REFERENCES sensor_nodes(node_id) ON DELETE CASCADE,
                    INDEX idx_node_ts (node_id, timestamp),
                    INDEX idx_ts (timestamp)
                )
            """)
            # notifications
            await cur.execute("""
                CREATE TABLE IF NOT EXISTS notifications (
                    id INT PRIMARY KEY AUTO_INCREMENT,
                    node_id VARCHAR(10),
                    title VARCHAR(200) NOT NULL,
                    message TEXT NOT NULL,
                    type ENUM('critical','warning','success','info') NOT NULL,
                    is_read BOOLEAN DEFAULT FALSE,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (node_id) REFERENCES sensor_nodes(node_id) ON DELETE SET NULL,
                    INDEX idx_created (created_at)
                )
            """)
            # ai_predictions
            await cur.execute("""
                CREATE TABLE IF NOT EXISTS ai_predictions (
                    id INT PRIMARY KEY AUTO_INCREMENT,
                    node_id VARCHAR(10) NOT NULL,
                    prediction_type VARCHAR(50) NOT NULL,
                    confidence DECIMAL(5,2) NOT NULL,
                    predicted_value DECIMAL(5,2),
                    prediction_time TIMESTAMP NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (node_id) REFERENCES sensor_nodes(node_id) ON DELETE CASCADE,
                    INDEX idx_node_time (node_id, prediction_time)
                )
            """)
            # Seed users — ip_address diisi saat login pertama kali
            # '127.0.0.1' untuk akses lokal, '0.0.0.0' untuk akses jaringan (wildcard)
            await cur.execute("""
                INSERT IGNORE INTO users (ip_address, access_code, name) VALUES
                ('127.0.0.1', 'ADMIN123',    'Admin Local'),
                ('0.0.0.0',   'SUSEMON2026', 'Admin Network')
            """)
            # Seed nodes
            await cur.execute("""
                INSERT IGNORE INTO sensor_nodes (node_id, node_name, location) VALUES
                ('A1','Node Sensor A1','Rack Server Utama'),
                ('B2','Node Sensor B2','Rack Server Backup'),
                ('C3','Node Sensor C3','Rack Network'),
                ('D4','Node Sensor D4','Rack Storage')
            """)
    logger.info("Database initialized")
