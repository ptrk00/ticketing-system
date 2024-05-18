from fastapi import FastAPI, Depends
import asyncpg
import os

app = FastAPI()

DATABASE_URL=os.getenv("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/mydb")

@app.on_event("startup")
async def startup():
    app.state.db: asyncpg.Pool = await asyncpg.create_pool(DATABASE_URL)

@app.on_event("shutdown")
async def shutdown():
    await app.state.db.close()

async def get_db() -> asyncpg.Pool:
    return app.state.db

@app.get("/events")
async def list_events(db: asyncpg.Pool = Depends(get_db)):
    async with db.acquire() as connection:
        events = await connection.fetch(
            """
            SELECT * FROM "event"
            """
        )
        return [dict(event) for event in events]


@app.get("/health")
async def root():
    return {"app": "helathy"}
