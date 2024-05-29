from fastapi import APIRouter, Depends, Query, Request
from fastapi.responses import HTMLResponse
from database.db import get_db
import asyncpg
from pydantic import BaseModel
from middlewares.middleware import get_accept_header
from fastapi.templating import Jinja2Templates
import datetime
import os

router = APIRouter()
templates = Jinja2Templates(directory="app/templates")

@router.get("/")
async def list_events(request: Request,
                        db: asyncpg.Pool = Depends(get_db), 
                        limit: int = Query(3, ge=1),
                        offset: int = Query(0, ge=0),
                        response_type: str = Depends(get_accept_header),
                        responce_class=HTMLResponse):
    async with db.acquire() as connection:
        events = await connection.fetch(
            """
            SELECT 
                *
            FROM event_overview
            ORDER BY id LIMIT $1 OFFSET $2
            """, limit, offset
        )
        total_events = await connection.fetchval("SELECT COUNT(*) FROM event")
        events = [dict(event) for event in events]
        if response_type == "json":
            return events
        else:
            return templates.TemplateResponse(
        request=request, name="events/events.html",
        context={"events": events, "total_events": total_events,
        "offset": offset, "limit": limit}
        )    
       

@router.get("/bestsellers")
async def get_best_selling_events(request: Request,
                                db: asyncpg.Pool = Depends(get_db),
                                response_type: str = Depends(get_accept_header),
                                responce_class=HTMLResponse):
    async with db.acquire() as connection:
        events = await connection.fetch(
            """
            SELECT distinct
                event.id,
                event.name,
                event.description,
                event.start_date,
                event.end_date,
                event.image_url,
                location.name as location_name,
                COUNT(ticket.id) over(partition by event.id) as tickets_sold
            FROM "ticket" 
                INNER JOIN event ON ticket.event_id = event.id 
                INNER JOIN location ON event.location_id = location.id
            ORDER BY tickets_sold DESC
            LIMIT 3
            """
        )
        events_popularity = await connection.fetch(
            """
            SELECT 
                e.id, 
                e.name, 
                e.genre,
                l.name as location_name, 
                popularity(e.seats, e.seats_capacity) over(partition by e.id) as event_popularity, 
                popularity(e.seats, e.seats_capacity) over(partition by e.genre) as genre_popularity, 
                popularity(e.seats, e.seats_capacity) over(partition by e.location_id) as location_popularity 
            FROM event e
                INNER JOIN location l
                    ON l.id = e.location_id
            ORDER BY event_popularity DESC
            LIMIT 10 
            """
        )
    events = [dict(event) for event in events]
    events_popularity = [dict(event) for event in events_popularity]
    if response_type == "json":
        return events
    else:
        return templates.TemplateResponse(
            request=request, name="events/event_bestsellers.html",
            context={"events": events, "event_popularity": events_popularity},
        )    

@router.get("/search")
async def search_for_events(request: Request,
                            q: str = Query(min_length=1), 
                            db: asyncpg.Pool = Depends(get_db),
                            response_type: str = Depends(get_accept_header),
                            responce_class=HTMLResponse):
    async with db.acquire() as connection:
        events = await connection.fetch(
            """
            SELECT * 
                FROM event_overview
            WHERE event_overview.name ILIKE $1
            """, f"%{q}%"
        )
        
    events = [dict(event) for event in events]
    if response_type == "json":
        return events
    else:
        return templates.TemplateResponse(
        request=request, name="events/events_text_search.html",
        context={"events": events}
    )    

@router.get("/search/description")
async def search_for_events_by_description(request: Request,
                            q: str = Query(min_length=1), 
                            db: asyncpg.Pool = Depends(get_db),
                            response_type: str = Depends(get_accept_header),
                            responce_class=HTMLResponse):
    async with db.acquire() as connection:
        events = await connection.fetch(
            """
         SELECT 
            *
         FROM event_overview
            WHERE event_overview.ts @@ to_tsquery('english', $1);
            """, q
        )
    if response_type == "json":
        return events
    else:
        return templates.TemplateResponse(
        request=request, name="events/events_text_search.html",
        context={"events": events}
    )    

# TODO: for now not implemented in ui
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
                event.name as name,
                l.name as location_name,
                ST_Y(ST_AsText(l.coordinates::geometry)) as latitude,
                ST_X(ST_AsText(l.coordinates::geometry)) as longitude,
                ST_Distance(coordinates, ST_GeogFromText($1)) AS distance
             FROM "event"
                INNER JOIN location l on event.location_id=l.id 
                WHERE ST_DWithin(l.coordinates, ST_GeogFromText($2), $3)
                ORDER BY distance ASC;
            """, f'POINT({long} {lat})', f'POINT({long} {lat})', range * 1000
        )
        return [dict(event) for event in events]

@router.get("/closerange")
async def search_events_in_range_view(request: Request,
                            response_type: str = Depends(get_accept_header),
                            responce_class=HTMLResponse):
    return templates.TemplateResponse(
        request=request, name="events/events_nearest.html",
        context={"api_key": os.getenv("GOOGLE_MAPS_API_KEY")})


@router.get("/nearest")
async def search_nearest_events(request: Request,
                            long: float = Query(),
                            lat: float = Query(),
                            db: asyncpg.Pool = Depends(get_db),
                            response_type: str = Depends(get_accept_header),
                            responce_class=HTMLResponse):
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
    events = [dict(event) for event in events]
    if response_type == "json":
        return events
    else:
        return templates.TemplateResponse(
        request=request, name="events/events_nearest.html",
        context={"events": events, "api_key": os.getenv("GOOGLE_MAPS_API_KEY")}
    )    

# TODO: for now not implemented in ui
@router.get("/{event_id}/artist")
async def get_events_artist( event_id: int, db: asyncpg.Pool = Depends(get_db)):
    async with db.acquire() as connection:
        events = await connection.fetch(
            """
            SELECT 
                event.id, 
                event.name, 
                array_agg(artist.name) as "artists" 
            FROM "event" 
                INNER JOIN location ON event.location_id = location.id 
                INNER JOIN event_artist ON event_artist.event_id=event.id
                INNER JOIN artist ON event_artist.artist_id=artist.id
            WHERE event.id = $1
            GROUP BY event.id, event.name
            """, event_id
        )
        return [dict(event) for event in events]


@router.get("/{event_id}")
async def get_events(request: Request,
                    event_id: int, 
                    db: asyncpg.Pool = Depends(get_db),
                    response_type: str = Depends(get_accept_header),
                    responce_class=HTMLResponse
                    ):
    async with db.acquire() as connection:
        event = await connection.fetchrow(
            """
        SELECT * FROM event_details e 
        WHERE e.id = $1
            """, event_id
        )
    if response_type == "json":
        return event
    else:
        return templates.TemplateResponse(
        request=request, name="events/event.html",
        context={"event": event, "api_key": os.getenv("GOOGLE_MAPS_API_KEY")}
    )    
     
class CreateEventPayload(BaseModel):
    name: str
    description: str
    start_date: datetime.date
    end_date: datetime.date
    seats: int
    location_id: int
    actors_ids: list[int]

@router.post("/event")
async def create_events(payload: CreateEventPayload, db: asyncpg.Pool = Depends(get_db)):
    async with db.acquire() as connection:
        async with connection.transaction():
            event_id = await connection.fetchval(
            """
                INSERT INTO "event" (name, description, start_date, end_date, seats, location_id)
                VALUES ($1, $2, $3, $4, $5, $6)
                RETURNING id
            """,
            payload.name, payload.description, payload.start_date, payload.end_date, payload.seats, payload.location_id
            )

            for actor_id in payload.actors_ids:
                await connection.execute(
                """
                    INSERT INTO "event_artist" (event_id, artist_id)
                    VALUES ($1, $2)
                """, event_id, actor_id
        
            )

        return