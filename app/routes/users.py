from fastapi import APIRouter, Depends, Query, Request
from fastapi.responses import HTMLResponse
from database.db import get_db
import asyncpg
from fastapi.templating import Jinja2Templates
from middlewares.middleware import get_accept_header

router = APIRouter()

templates = Jinja2Templates(directory="app/templates")

@router.get("/")
async def list_users(request: Request, 
                        db: asyncpg.Pool = Depends(get_db), 
                        limit: int = Query(3, ge=1),
                        offset: int = Query(0, ge=0),
                        response_type: str = Depends(get_accept_header),
                        response_class=HTMLResponse):
    async with db.acquire() as connection:
        users = await connection.fetch(
            """
            SELECT 
                id,
                name,
                email,
                birthdate
            FROM "user" 
            ORDER BY id LIMIT $1 OFFSET $2
            """, limit, offset
        )
        # needed for pagination
        total_users = await connection.fetchval("SELECT COUNT(*) FROM \"user\"")

    all_users = [dict(user) for user in users]
    if response_type == "json":
        return all_users
    else:
        return templates.TemplateResponse(
        request=request, name="users/users.html",
        context={"users": all_users, "limit": limit, "offset": offset, "total_users": total_users}
    )

@router.get("/{user_id}")
async def get_user(request: Request,
                    user_id: int, 
                    db: asyncpg.Pool = Depends(get_db),
                    response_type: str = Depends(get_accept_header)):
    async with db.acquire() as connection:
        user = await connection.fetchrow(
            """
            SELECT 
                id, 
                name,
                email,
                birthdate
            FROM "user" 
            WHERE id = $1
            """, user_id
        )
    # user = [dict(user) for user in users]
    if response_type == "json":
        return user
    else:
        return templates.TemplateResponse(
        request=request, name="users/user.html",
        context={"user": user}
    )    

@router.get("/{user_id}/tickets")
async def get_user_tickets(request: Request,
                            user_id: int, 
                            db: asyncpg.Pool = Depends(get_db),
                            response_type: str = Depends(get_accept_header)):
    async with db.acquire() as connection:
        result = await connection.fetch(
            """
            SELECT 
                "user".id as owner_id, 
                "user".name,
                "user".email,
                ticket.id as ticket_id,
                ticket.price,
                ticket.currency,
                event.name as event_name,
                location.name as location_name
            FROM "user" 
            INNER JOIN "ticket" ON "user".id=ticket.owner_id
            INNER JOIN "event" ON ticket.event_id=event.id
            INNER JOIN "location" ON event.location_id=location.id
            WHERE "user".id = $1
            """, user_id
        )
    tickets = [dict(result) for result in result]
    if response_type == "json":
        return tickets
    else:
        return templates.TemplateResponse(
        request=request, name="users/user_tickets.html",
        context={"tickets": tickets, "user_id": user_id}
    )    
    

@router.get("/{user_id}/tickets/{ticket_id}")
async def get_user_ticket(request: Request,
                          user_id: int, 
                          ticket_id: int, 
                          db: asyncpg.Pool = Depends(get_db),
                          response_type: str = Depends(get_accept_header)
                          ):
    async with db.acquire() as connection:
        ticket = await connection.fetchrow(
            """
            SELECT 
                "user".id as owner_id, 
                "user".name,
                "user".email,
                ticket.id as ticket_id,
                ticket.price,
                ticket.currency,
                event.name as event_name,
                location.name as location_name
            FROM "user" 
            INNER JOIN "ticket" ON "user".id=ticket.owner_id
            INNER JOIN "event" ON ticket.event_id=event.id
            INNER JOIN "location" ON event.location_id=location.id
            WHERE "user".id = $1 AND ticket.id = $2
            """, user_id, ticket_id
        )
    if response_type == "json":
        return ticket
    else:
        return templates.TemplateResponse(
        request=request, name="users/user_ticket.html",
        context={"ticket": ticket, "user_id": user_id}
    )    