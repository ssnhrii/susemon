"""
Script migrasi — hash semua access code yang masih plain text di database
Jalankan SEKALI setelah update ke versi dengan bcrypt:

    python migrate_passwords.py

Script ini aman dijalankan berkali-kali — hanya memproses yang belum di-hash.
"""
import asyncio
import aiomysql
import bcrypt
from dotenv import load_dotenv
import os

load_dotenv()


def is_hashed(value: str) -> bool:
    return value.startswith("$2b$") or value.startswith("$2a$")


async def migrate():
    conn = await aiomysql.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=int(os.getenv("DB_PORT", 3306)),
        user=os.getenv("DB_USER", "root"),
        password=os.getenv("DB_PASSWORD", ""),
        db=os.getenv("DB_NAME", "susemon_db"),
        autocommit=True,
    )
    async with conn.cursor() as cur:
        await cur.execute("SELECT id, ip_address, access_code FROM users")
        users = await cur.fetchall()

        migrated = 0
        skipped  = 0

        for user_id, ip, code in users:
            if is_hashed(code):
                print(f"  [SKIP] id={user_id} ip={ip} — sudah di-hash")
                skipped += 1
            else:
                hashed = bcrypt.hashpw(code.encode("utf-8"), bcrypt.gensalt(rounds=12)).decode()
                await cur.execute(
                    "UPDATE users SET access_code=%s WHERE id=%s",
                    (hashed, user_id)
                )
                print(f"  [HASH] id={user_id} ip={ip} — berhasil di-hash")
                migrated += 1

    conn.close()
    print(f"\nSelesai: {migrated} di-hash, {skipped} dilewati")


if __name__ == "__main__":
    print("=== Migrasi Password SUSEMON ===")
    asyncio.run(migrate())
