"""
Script cepat untuk tambah user baru ke database SUSEMON.
Jalankan dari folder backend:  python add_user.py
"""
import asyncio
import aiomysql
import bcrypt
from dotenv import load_dotenv
import os

load_dotenv()

USERS_TO_ADD = [
    # (ip_address, access_code, name, role)
    ("172.20.10.4",  "ADMIN123",   "Admin WiFi Hotspot",   "admin"),
    ("192.168.1.1",  "ADMIN123",   "Admin LAN",             "admin"),
    ("192.168.0.1",  "ADMIN123",   "Admin LAN Alt",         "admin"),
]

def hash_pw(plain: str) -> str:
    return bcrypt.hashpw(plain.encode("utf-8")[:72], bcrypt.gensalt(rounds=12)).decode()

async def main():
    conn = await aiomysql.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=int(os.getenv("DB_PORT", 3306)),
        user=os.getenv("DB_USER", "root"),
        password=os.getenv("DB_PASSWORD", ""),
        db=os.getenv("DB_NAME", "susemon_db"),
        autocommit=True,
    )
    async with conn.cursor() as cur:
        print("=== Tambah User SUSEMON ===\n")
        for ip, code, name, role in USERS_TO_ADD:
            await cur.execute("SELECT id FROM users WHERE ip_address=%s", (ip,))
            if await cur.fetchone():
                print(f"  [SKIP] {ip} — sudah ada")
                continue
            hashed = hash_pw(code)
            await cur.execute(
                "INSERT INTO users (ip_address, access_code, name, role) VALUES (%s,%s,%s,%s)",
                (ip, hashed, name, role)
            )
            print(f"  [OK]   {ip} — ditambahkan (code: {code})")

        print("\n=== Daftar Semua User ===")
        await cur.execute("SELECT id, ip_address, name, role FROM users ORDER BY id")
        rows = await cur.fetchall()
        for r in rows:
            print(f"  ID:{r[0]}  IP:{r[1]:<20} Nama:{r[2]:<25} Role:{r[3]}")

    conn.close()
    print("\nSelesai!")

if __name__ == "__main__":
    asyncio.run(main())
