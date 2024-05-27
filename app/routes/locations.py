from fastapi import APIRouter, Depends, Query, Request
from fastapi.responses import HTMLResponse
from database.db import get_db
import asyncpg
from middlewares.middleware import get_accept_header
from fastapi.templating import Jinja2Templates
import os

router = APIRouter()
templates = Jinja2Templates(directory="app/templates")

@router.get("/")
async def list_locations(request: Request,
                        db: asyncpg.Pool = Depends(get_db), 
                        limit: int = Query(3, ge=1),
                        offset: int = Query(0, ge=0),
                        response_type: str = Depends(get_accept_header),
                        responce_class=HTMLResponse):
    async with db.acquire() as connection:
        locations = await connection.fetch(
            """
            SELECT 
                id, 
                name, 
                seats as max_seats,
                image_url,
                description, 
                coordinates
            FROM "location" 
            ORDER BY id LIMIT $1 OFFSET $2
            """, limit, offset
        )
        total_locations = await connection.fetchval("SELECT COUNT(*) FROM event")
    locations = [dict(location) for location in locations]
    if response_type == "json":
        return locations
    else:
        return templates.TemplateResponse(
    request=request, name="locations/locations.html",
    context={"locations": locations, "total_locations": total_locations,
    "offset": offset, "limit": limit}
    )    


@router.get("/{location_id}")
async def get_events(request: Request,
                    location_id: int, db: asyncpg.Pool = Depends(get_db),
                    response_type: str = Depends(get_accept_header),
                    responce_class=HTMLResponse):
    async with db.acquire() as connection:
        location = await connection.fetchrow(
            """
            WITH closest_event AS (
                SELECT
                    event.id,
                    event.name,
                    event.start_date,
                    event.seats as seats_left,
                    event.image_url,
                    event.description
                FROM
                    event
                WHERE event.location_id = $1
                AND current_date < event.start_date
                ORDER BY start_date ASC LIMIT 1
            )

            SELECT 
                location.id, 
                location.name,
                location.image_url, 
                seats as max_seats, 
                ST_Y(ST_AsText(location.coordinates::geometry)) as latitude,
                ST_X(ST_AsText(location.coordinates::geometry)) as longitude,
                location.description,
                closest_event.name as closest_event_name,
                closest_event.start_date as closest_event_start_date,
                closest_event.seats_left as closest_event_seats_left,
                closest_event.image_url as closest_event_image_url,
                closest_event.description as closest_event_description,
                closest_event.id as closest_event_id
            FROM "location", closest_event 
            WHERE location.id = $1
            """, location_id
        )
    if response_type == "json":
        return location
    else:
        return templates.TemplateResponse(
    request=request, name="locations/location.html",
    context={"location": location, "api_key": os.getenv("GOOGLE_MAPS_API_KEY")}
    )    