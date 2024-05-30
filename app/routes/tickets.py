from fastapi import APIRouter, Depends, Query, Request, Form
from typing import Annotated
from database.db import get_db
import asyncpg
from middlewares.middleware import get_accept_header
from fastapi.templating import Jinja2Templates
from fastapi.responses import HTMLResponse

router = APIRouter()
templates = Jinja2Templates(directory="app/templates")

@router.get("/")
async def list_tickets(request: Request,
                        db: asyncpg.Pool = Depends(get_db), 
                        limit: int = Query(3, ge=1),
                        offset: int = Query(0, ge=0),
                       response_type: str = Depends(get_accept_header),
                        responce_class=HTMLResponse ):
    async with db.acquire() as connection:
        tickets = await connection.fetch(
            """
            SELECT 
                *
            FROM ticket_overview
            ORDER BY id LIMIT $1 OFFSET $2
            """, limit, offset
        )
        total_tickets = await connection.fetchval("SELECT COUNT(*) FROM ticket")
    tickets = [dict(ticket) for ticket in tickets]
    if response_type == "json":
        return tickets
    else:
        return templates.TemplateResponse(
    request=request, name="tickets/tickets.html",
    context={"tickets": tickets, "total_tickets": total_tickets,
    "offset": offset, "limit": limit}
    )    


@router.get("/{ticket_id}")
async def get_ticket(request: Request,
                        ticket_id: int, 
                        db: asyncpg.Pool = Depends(get_db),
                        response_type: str = Depends(get_accept_header),
                        responce_class=HTMLResponse ):
    async with db.acquire() as connection:
        ticket = await connection.fetchrow(
            """
            SELECT 
                *
            FROM ticket_details
            WHERE ticket_details.id=$1
            """, ticket_id
        )
    if response_type == "json":
        return ticket
    else:
        return templates.TemplateResponse(
    request=request, name="tickets/ticket.html",
    context={"ticket": ticket}
    )    

@router.post("/checkout")
async def buy_ticket(request: Request,
                        user_id : Annotated[int, Form()], 
                        event_id : Annotated[int, Form()],
                        db: asyncpg.Pool = Depends(get_db)):
    async with db.acquire() as connection:
        await connection.execute(
            """
            SELECT 
                buy_ticket($1, $2)

            """, user_id, event_id
        )
    return templates.TemplateResponse(
        request=request, name="tickets/ticket_bought.html",
        context={"user_id": user_id, "event_id": event_id}
    )