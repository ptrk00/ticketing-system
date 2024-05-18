from fastapi import APIRouter, Depends, Query
from database.db import get_db
import asyncpg

router = APIRouter()

@router.get("/")
async def list_locations(db: asyncpg.Pool = Depends(get_db), 
                        limit: int = Query(3, ge=1),
                        offset: int = Query(0, ge=0)):
    async with db.acquire() as connection:
        events = await connection.fetch(
            """
            SELECT 
                id, 
                name, 
                seats as max_seats, 
                coordinates
            FROM "location" 
            ORDER BY id LIMIT $1 OFFSET $2
            """, limit, offset
        )
        return [dict(event) for event in events]

@router.get("/{location_id}")
async def get_events( location_id: int, db: asyncpg.Pool = Depends(get_db)):
    async with db.acquire() as connection:
        events = await connection.fetch(
            """
            SELECT 
                id, 
                name, 
                seats as max_seats, 
                coordinates
            FROM "location" 
            WHERE id = $1
            """, location_id
        )
        return [dict(event) for event in events]