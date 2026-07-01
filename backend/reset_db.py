import asyncio
import os
import aiomysql
from dotenv import load_dotenv

# Load env variables from backend/.env
load_dotenv()

async def reset_database():
    print("Connecting to MySQL Server...")
    # Connect to MySQL server without specifying the database
    conn = await aiomysql.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=int(os.getenv("DB_PORT", 3306)),
        user=os.getenv("DB_USER", "root"),
        password=os.getenv("DB_PASSWORD", ""),
        autocommit=True
    )
    
    async with conn.cursor() as cur:
        # 1. Drop the database
        print("Dropping database 'susemon_db'...")
        await cur.execute("DROP DATABASE IF EXISTS susemon_db")
        
        # 2. Read the SQL initialization script
        sql_file_path = os.path.join(os.path.dirname(__file__), "init_db.sql")
        print(f"Reading initialization script from {sql_file_path}...")
        with open(sql_file_path, "r", encoding="utf-8") as f:
            sql_script = f.read()
            
        # 3. Parse and run statements
        # Splitting by ';' to execute queries sequentially
        statements = sql_script.split(";")
        
        print("Recreating database susemon_db and running tables initialization...")
        for stmt in statements:
            stmt_clean = stmt.strip()
            if not stmt_clean:
                continue
            try:
                await cur.execute(stmt_clean)
            except Exception as e:
                # Log warning for statements that might fail if already created
                print(f"Warning/Error executing: {stmt_clean[:60]}... -> {e}")
                
        print("Database has been completely reset and initialized successfully!")
        
    conn.close()

if __name__ == "__main__":
    asyncio.run(reset_database())
