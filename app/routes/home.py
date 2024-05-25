from fastapi import APIRouter, Depends, Query, Request
from fastapi.responses import HTMLResponse
from database.db import get_db
import asyncpg
from fastapi.templating import Jinja2Templates

router = APIRouter()
templates = Jinja2Templates(directory="app/templates")

@router.get("/")
async def home_page(request: Request, db: asyncpg.Pool = Depends(get_db), 
                        limit: int = Query(3, ge=1),
                        offset: int = Query(0, ge=0),
                        response_class=HTMLResponse):

    async with db.acquire() as connection:
        events = await connection.fetch(
            """
             SELECT 
                * FROM soon_sold_out_events
            """
        )
    return templates.TemplateResponse(
        request=request, name="home.html",
        context={"events": events}
    )