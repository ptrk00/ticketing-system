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

@router.get("/bestsellers")
async def get_best_selling_events(db: asyncpg.Pool = Depends(get_db)):
    async with db.acquire() as connection:
        events = await connection.fetch(
            """
            SELECT 
                event.name,
                COUNT(ticket.id) as tickets_sold
            FROM "ticket" 
                INNER JOIN event ON ticket.event_id = event.id 
                INNER JOIN location ON event.location_id = location.id
            GROUP BY event.name
            ORDER BY tickets_sold DESC
            LIMIT 3
            """
        )
        return [dict(event) for event in events]

@router.get("/search")
async def search_for_events(q: str = Query(min_length=1), 
                            db: asyncpg.Pool = Depends(get_db)):
    async with db.acquire() as connection:
        events = await connection.fetch(
            """
             SELECT 
                event.id,
                event.name 
             FROM "event" 
                WHERE event.name ILIKE $1
            """, f"%{q}%"
        )
        return [dict(event) for event in events]

@router.get("/search/description")
async def search_for_events_by_description(q: str = Query(min_length=1), 
                            db: asyncpg.Pool = Depends(get_db)):
    async with db.acquire() as connection:
        events = await connection.fetch(
            """
         SELECT 
            event.name as event_name, 
            event.description
         FROM event 
            WHERE ts @@ to_tsquery('english', $1);
            """, q
        )
        return [dict(event) for event in events]

@router.get("/search/description/all")
async def search_for_events_by_descriptio_full_rankn(q: str = Query(min_length=1), 
                            db: asyncpg.Pool = Depends(get_db)):
    async with db.acquire() as connection:
        events = await connection.fetch(
            """
         SELECT 
            event.name as event_name, 
            event.description,
            ts_rank(ts, to_tsquery('english', $1)) 
        FROM event 
            ORDER BY ts_rank(ts, to_tsquery('english', $1)) DESC;
            """, q
        )
        return [dict(event) for event in events]

@router.get("/range")
async def search_events_in_range(range: int = Query(gt=1),
                            long: float = Query(),
                            lat: float = Query(),
                            db: asyncpg.Pool = Depends(get_db)):
    async with db.acquire() as connection:
        events = await connection.fetch(
            """
             SELECT 
                event.id,
                event.name as event_name,
                location.name as location_name,
                ST_Distance(coordinates, ST_GeogFromText($1)) AS distance
             FROM "event"
                INNER JOIN location on event.location_id=location.id 
                WHERE ST_DWithin(location.coordinates, ST_GeogFromText($2), $3);
            """, f'POINT({long} {lat})', f'POINT({long} {lat})', range
        )
        return [dict(event) for event in events]

@router.get("/nearest")
async def search_nearest_events(long: float = Query(),
                            lat: float = Query(),
                            db: asyncpg.Pool = Depends(get_db)):
    async with db.acquire() as connection:
        events = await connection.fetch(
            """
             SELECT 
                event.id as event_id,
                event.name as event_name,
                location.name as location_name,
                ST_Distance(coordinates, ST_GeogFromText($1)) AS distance
             FROM "event"
                INNER JOIN location on event.location_id=location.id 
                ORDER BY location.coordinates <-> ST_GeogFromText($2)
            """, f'POINT({long} {lat})', f'POINT({long} {lat})'
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