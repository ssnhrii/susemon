import asyncio
import os
import aiomysql
from dotenv import load_dotenv

# Load env variables from backend/.env
load_dotenv()

async def clear_dummy_data():
    print("Connecting to MySQL Database...")
    conn = await aiomysql.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=int(os.getenv("DB_PORT", 3306)),
        user=os.getenv("DB_USER", "root"),
        password=os.getenv("DB_PASSWORD", ""),
        db=os.getenv("DB_NAME", "susemon_db")
    )
    
    async with conn.cursor() as cur:
        # 1. Clear all notification logs
        print("Clearing notifications table...")
        await cur.execute("DELETE FROM notifications")
        
        # 2. Clear all historical telemetry readings
        print("Clearing sensor_data table...")
        await cur.execute("DELETE FROM sensor_data")
        
        # 3. Clear all AI predictions
        print("Clearing ai_predictions table...")
        await cur.execute("DELETE FROM ai_predictions")
        
        # 4. Remove all dummy sensor nodes, keeping only the real 'TA11' node
        print("Removing dummy sensor nodes...")
        await cur.execute("DELETE FROM sensor_nodes WHERE node_id NOT IN ('TA11')")
        
        # Commit the transaction
        await conn.commit()
        
        # Show status
        await cur.execute("SELECT COUNT(*) FROM sensor_nodes")
        nodes_left = (await cur.fetchone())[0]
        await cur.execute("SELECT COUNT(*) FROM sensor_data")
        data_left = (await cur.fetchone())[0]
        
        print(f"Cleanup complete! Nodes left: {nodes_left}, Sensor readings left: {data_left}")
        
    conn.close()

if __name__ == "__main__":
    asyncio.run(clear_dummy_data())
