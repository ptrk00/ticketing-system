import asyncpg 
import os

DATABASE_URL=os.getenv("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/mydb")
db = None

async def db_startup():
    global db
    db = await asyncpg.create_pool(DATABASE_URL)

async def db_shutdown():
    await db.close()

async def get_db() -> asyncpg.Pool:
    return db
