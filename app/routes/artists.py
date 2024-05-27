from fastapi import APIRouter, Depends, Query, Request
from database.db import get_db
import asyncpg
from middlewares.middleware import get_accept_header
from fastapi.templating import Jinja2Templates
from fastapi.responses import HTMLResponse

router = APIRouter()
templates = Jinja2Templates(directory="app/templates")

@router.get("/")
async def list_artists(request: Request,
                        db: asyncpg.Pool = Depends(get_db), 
                        limit: int = Query(3, ge=1),
                        offset: int = Query(0, ge=0),
                        response_type: str = Depends(get_accept_header),
                        responce_class=HTMLResponse):
    async with db.acquire() as connection:
        artists = await connection.fetch(
            """
            SELECT 
                artist.id, 
                artist.name,
                artist.image_url
            FROM "artist" 
            ORDER BY id LIMIT $1 OFFSET $2
            """, limit, offset
        )
        total_artists = await connection.fetchval("SELECT COUNT(*) FROM artist")
    artists = [dict(artist) for artist in artists]
    if response_type == "json":
        return artists
    else:
        return templates.TemplateResponse(
    request=request, name="artists/artists.html",
    context={"artists": artists, "total_artists": total_artists,
    "offset": offset, "limit": limit}
    )    

@router.get("/{artist_id}")
async def get_artists(request: Request,  
                        artist_id: int, 
                        db: asyncpg.Pool = Depends(get_db),
                        response_type: str = Depends(get_accept_header),
                        responce_class=HTMLResponse
):
    async with db.acquire() as connection:
        artist = await connection.fetchrow(
            """
            SELECT 
                artist.name,
                artist.image_url,
                array_agg((event.id, event.name)) as events
            FROM "artist" 
                INNER JOIN event_artist ON event_artist.artist_id=artist.id
                INNER JOIN event ON event_artist.event_id=event.id
            WHERE artist.id = $1
            GROUP BY artist.name, artist.image_url
            """, artist_id
        )
    if response_type == "json":
        return artist
    else:
        return templates.TemplateResponse(
    request=request, name="artists/artist.html",
    context={"artist": artist}
    )    