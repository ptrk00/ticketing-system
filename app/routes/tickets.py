from fastapi import APIRouter, Depends, Query
from database.db import get_db
import asyncpg

router = APIRouter()

@router.get("/")
async def list_tickets(db: asyncpg.Pool = Depends(get_db), 
                        limit: int = Query(3, ge=1),
                        offset: int = Query(0, ge=0)):
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
        return [dict(ticket) for ticket in tickets]

@router.get("/{ticket_id}")
async def get_ticket(ticket_id: int, db: asyncpg.Pool = Depends(get_db)):
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
            WHERE ticket.id=$1
            """, ticket_id
        )
        return [dict(ticket) for ticket in tickets]