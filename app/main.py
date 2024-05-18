from fastapi import FastAPI, Depends, Query
import asyncpg
import os
from routes import events, locations
from database.db import db_startup, db_shutdown

app = FastAPI()

app.include_router(events.router, prefix="/events", tags=["event"])
app.include_router(locations.router, prefix="/locations", tags=["event"])

@app.on_event("startup")
async def startup():
    await db_startup()

@app.on_event("shutdown")
async def shutdown():
    await db_shutdown()

@app.get("/health")
async def root():
    return {"app": "helathy"}
