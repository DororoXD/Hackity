"""SQLite tables and the DB session. The DB file is created next to this file on first run."""
import csv
import os
from datetime import date
from pathlib import Path
from typing import Optional

from sqlmodel import Field, Session, SQLModel, create_engine, select

BACKEND_DIR = Path(__file__).resolve().parent
CATALOG_CSV = BACKEND_DIR.parent / "data" / "product_catalog.csv"
DB_URL = os.environ.get("PANTRYPAL_DB_URL", f"sqlite:///{BACKEND_DIR / 'pantrypal.db'}")

engine = create_engine(DB_URL, connect_args={"check_same_thread": False})


class Product(SQLModel, table=True):
    product_id: int = Field(primary_key=True)
    name: str
    category: str
    shelf_life_days: int
    unit: str


class Batch(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    product_id: int = Field(foreign_key="product.product_id", index=True)
    quantity: float  # remaining, in the product's unit
    received_date: date
    expiry_date: date  # last day the batch can be sold
    status: str = "active"  # active | sold_out | discarded | donated
    discount_pct: int = 0  # markdown already applied to this batch; 0 = full price


class Sale(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    product_id: int = Field(foreign_key="product.product_id", index=True)
    sale_date: date = Field(index=True)
    quantity: float


class SalesImport(SQLModel, table=True):
    """One POS file that was imported (not dry runs)."""
    id: Optional[int] = Field(default=None, primary_key=True)
    filename: str
    imported_on: date
    rows_imported: int
    rows_rejected: int


def get_session():
    with Session(engine) as session:
        yield session


def init_db():
    """Create the tables and load the product catalog the first time."""
    SQLModel.metadata.create_all(engine)
    with engine.begin() as conn:  # databases made before batches had discount_pct
        columns = {row[1] for row in conn.exec_driver_sql("PRAGMA table_info(batch)")}
        if "discount_pct" not in columns:
            conn.exec_driver_sql("ALTER TABLE batch ADD COLUMN discount_pct INTEGER NOT NULL DEFAULT 0")
    with Session(engine) as session:
        if session.exec(select(Product)).first() is not None:
            return
        with open(CATALOG_CSV, newline="") as f:
            for row in csv.DictReader(f):
                session.add(Product(
                    product_id=int(row["product_id"]), name=row["name"], category=row["category"],
                    shelf_life_days=int(row["shelf_life_days"]), unit=row["unit"],
                ))
        session.commit()
