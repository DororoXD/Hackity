"""PantryPal API. Run from this folder: uvicorn main:app --reload --host 0.0.0.0
Interactive docs: http://localhost:8000/docs
Set PANTRYPAL_TODAY=YYYY-MM-DD to run on a fixed demo date (see clock.py).
"""
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

import clock
from database import init_db
from routes import alerts, batches, sales_import, stock
from schemas import TodayOut


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    yield


app = FastAPI(title="PantryPal API", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

for module in (batches, stock, sales_import, alerts):
    app.include_router(module.router)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/today", response_model=TodayOut)
def today():
    """The date the app is running on, for the date shown in the app's header."""
    return TodayOut(today=clock.today())
