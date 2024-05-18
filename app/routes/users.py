from fastapi import APIRouter, Depends, Query
from database.db import get_db
import asyncpg

router = APIRouter()

@router.get("/")
async def list_users(db: asyncpg.Pool = Depends(get_db), 
                        limit: int = Query(3, ge=1),
                        offset: int = Query(0, ge=0)):
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
        return [dict(user) for user in users]

@router.get("/{user_id}")
async def get_user(user_id: int, db: asyncpg.Pool = Depends(get_db)):
    async with db.acquire() as connection:
        users = await connection.fetch(
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
        return [dict(user) for user in users]

@router.get("/{user_id}/tickets")
async def get_user_tickets(user_id: int, db: asyncpg.Pool = Depends(get_db)):
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
        return [dict(result) for result in result]

@router.get("/{user_id}/tickets/{ticket_id}")
async def get_user_ticket(user_id: int, ticket_id: int, db: asyncpg.Pool = Depends(get_db)):
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
            WHERE "user".id = $1 AND ticket.id = $2
            """, user_id, ticket_id
        )
        return [dict(result) for result in result]


@router.get("/{user_id}/tickets")
async def get_user_tickets(user_id: int, db: asyncpg.Pool = Depends(get_db)):
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
            WHERE "user".id = $1 GROUP BY location.id
            """, user_id
        )
        return [dict(result) for result in result]