from fastapi import APIRouter, Depends, Query
from database.db import get_db
import asyncpg

router = APIRouter()

@router.get("/")
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

@router.get("/{event_id}")
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