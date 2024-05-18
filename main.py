from fastapi import FastAPI, Depends, Query
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
async def list_events(db: asyncpg.Pool = Depends(get_db), 
                        limit: int = Query(3, ge=1),
                        offset: int = Query(0, ge=0)):
    async with db.acquire() as connection:
        events = await connection.fetch(
            """
            SELECT 
                event.id, 
                event.name, 
                description, 
                start_date, 
                end_date, 
                event.seats as "seats_left", 
                location.name as "location_name" 
            FROM "event" 
                INNER JOIN location ON event.location_id = location.id 
            ORDER BY id LIMIT $1 OFFSET $2
            """, limit, offset
        )
        return [dict(event) for event in events]

@app.get("/events/{event_id}")
async def get_events( event_id: int, db: asyncpg.Pool = Depends(get_db)):
    async with db.acquire() as connection:
        events = await connection.fetch(
            """
            SELECT 
                event.id, 
                event.name, 
                description, 
                start_date, 
                end_date, 
                event.seats as "seats_left", 
                location.name as "location_name" 
            FROM "event" 
                INNER JOIN location ON event.location_id = location.id 
            WHERE event.id = $1
            """, event_id
        )
        return [dict(event) for event in events]

@app.get("/health")
async def root():
    return {"app": "helathy"}
