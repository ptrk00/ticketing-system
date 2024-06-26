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
                *
            FROM location_overview
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

@router.get("/delete")
async def delete_location_page(request: Request,
                            db: asyncpg.Pool = Depends(get_db)):
    async with db.acquire() as connection:
        locations  = await connection.fetch(
            """
                SELECT 
                    id,
                    name
                FROM
                   location 
            """
        )

        locations = [dict(location) for location in locations]
        return templates.TemplateResponse(
            request=request, name="locations/location_delete.html",
            context={"locations": locations}
        )

@router.delete("/{location_id}")
async def delete_location(request: Request,
                        location_id: int,
                        db: asyncpg.Pool = Depends(get_db)):
    async with db.acquire() as connection:
        await connection.fetch(
            """
                SELECT
                    delete_location($1)
            """, location_id)

@router.get("/{location_id}")
async def get_events(request: Request,
                    location_id: int, db: asyncpg.Pool = Depends(get_db),
                    response_type: str = Depends(get_accept_header),
                    responce_class=HTMLResponse):
    async with db.acquire() as connection:
        location = await connection.fetchrow(
            """
            SELECT 
                *
            FROM location_details
            WHERE location_details.id = $1
            """, location_id
        )
    if response_type == "json":
        return location
    else:
        return templates.TemplateResponse(
    request=request, name="locations/location.html",
    context={"location": location, "api_key": os.getenv("GOOGLE_MAPS_API_KEY")}
    )    