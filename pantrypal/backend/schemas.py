"""Request and response models: the contract with the Flutter app. Keep lib/models/*.dart in sync."""
from datetime import date
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


class BatchStatus(str, Enum):
    active = "active"
    sold_out = "sold_out"
    discarded = "discarded"


class IssueType(str, Enum):
    expired = "expired"
    expiring_soon = "expiring_soon"


class Action(str, Enum):
    remove = "remove"
    discount = "discount"
    donate = "donate"
    monitor = "monitor"


class RowStatus(str, Enum):
    ok = "ok"
    unmatched = "unmatched"  # product not in the catalog
    bad_date = "bad_date"
    bad_quantity = "bad_quantity"


class Priority(str, Enum):
    high = "high"
    medium = "medium"
    low = "low"


class ProductOut(BaseModel):
    product_id: int
    name: str
    category: str
    shelf_life_days: int
    unit: str


class BatchCreate(BaseModel):
    product_id: int
    quantity: float = Field(gt=0)
    received_date: Optional[date] = None  # defaults to today
    expiry_date: Optional[date] = None  # defaults to received_date + the product's shelf life


class BatchUpdate(BaseModel):
    quantity: Optional[float] = Field(default=None, ge=0)
    status: Optional[BatchStatus] = None


class BatchOut(BaseModel):
    id: int
    product_id: int
    name: str
    unit: str
    quantity: float
    received_date: date
    expiry_date: date
    days_left: int  # negative once expired
    status: BatchStatus


class StockItem(BaseModel):
    product_id: int
    name: str
    category: str
    unit: str
    quantity: float  # total across active batches
    active_batches: int
    next_expiry: Optional[date]


class ImportRow(BaseModel):
    row: int  # line number in the CSV, header is line 1
    sale_date: Optional[date]
    product: str  # as written in the file
    product_id: Optional[int]  # the catalog product it matched
    name: Optional[str]
    quantity: Optional[float]
    status: RowStatus


class ImportRecord(BaseModel):
    id: int
    filename: str
    imported_on: date
    rows_imported: int
    rows_rejected: int  # unmatched products, bad dates and bad quantities


class SalesImportResult(BaseModel):
    rows: list[ImportRow]
    ok: int
    unmatched: int
    errors: int  # bad dates or quantities
    imported: int  # rows saved; 0 on a dry run


class Alert(BaseModel):
    batch_id: int
    product_id: int
    name: str
    quantity: float
    unit: str
    days_left: int
    priority: Priority
    issue_type: IssueType
    action: Action
    discount_pct: int  # 0 unless action is discount
    risk: float  # chance (0-1) that some of the batch goes unsold
    expected_waste_units: float
    rm_at_risk: float  # expected waste valued at the normal price
    expected_rm_saved: float  # extra RM the recommended action should earn versus doing nothing
    explanation: str
