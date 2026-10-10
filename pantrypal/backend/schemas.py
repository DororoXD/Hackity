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


class RowError(BaseModel):
    row: int  # line number in the CSV, header is line 1
    error: str


class SalesImportResult(BaseModel):
    rows_imported: int
    rows_rejected: list[RowError]


class Alert(BaseModel):
    batch_id: int
    product_id: int
    name: str
    issue_type: IssueType
    priority: Priority
    quantity: float
    unit: str
    days_left: int
    expected_unsold: float  # how much of the batch is unlikely to sell before it expires
    message: str
    suggested_action: str
