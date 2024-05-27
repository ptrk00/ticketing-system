from fastapi import APIRouter, Depends, Query, Request
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
                ticket.id,
                event.name as event,
                "user".name as owner_name,
                "user".email as owner_email,
                price,
                currency
            FROM "ticket"
            INNER JOIN "user" ON ticket.owner_id="user".id
            INNER JOIN "event" ON ticket.event_id=event.id 
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
                ticket.id,
                event.name as event,
                event.start_date as event_start_date,
                "user".name as owner_name,
                "user".email as owner_email,
                price,
                currency,
                bought_at,
                revoked
            FROM "ticket"
            INNER JOIN "user" ON ticket.owner_id="user".id
            INNER JOIN "event" ON ticket.event_id=event.id 
            WHERE ticket.id=$1
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
async def buy_ticket(user_id: int, 
                     event_id: int,
                     price: float,
                     currency: str = Query("PLN", len=3),
                    db: asyncpg.Pool = Depends(get_db)):
    async with db.acquire() as connection:
        tickets = await connection.execute(
            """
            INSERT INTO ticket 
                (owner_id, event_id, price, currency)
            VALUES ($1, $2, $3, $4)
            """, user_id, event_id, price, currency
        )
        print(tickets)
        return