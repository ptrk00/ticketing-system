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