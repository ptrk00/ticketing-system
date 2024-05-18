from fastapi import APIRouter, Depends, Query
from database.db import get_db
import asyncpg

router = APIRouter()

@router.get("/")
async def list_artists(db: asyncpg.Pool = Depends(get_db), 
                        limit: int = Query(3, ge=1),
                        offset: int = Query(0, ge=0)):
    async with db.acquire() as connection:
        artists = await connection.fetch(
            """
            SELECT 
                artist.id, 
                artist.name
            FROM "artist" 
            ORDER BY id LIMIT $1 OFFSET $2
            """, limit, offset
        )
        return [dict(artist) for artist in artists]

@router.get("/{artist_id}")
async def get_artists( artist_id: int, db: asyncpg.Pool = Depends(get_db)):
    async with db.acquire() as connection:
        artists = await connection.fetch(
            """
            SELECT 
                artist.name as artist_name,
                array_agg(event.name) as event_name
            FROM "artist" 
                INNER JOIN event_artist ON event_artist.artist_id=artist.id
                INNER JOIN event ON event_artist.event_id=event.id
            WHERE artist.id = $1
            GROUP BY artist.name
            """, artist_id
        )
        return [dict(artist) for artist in artists]