import csv
import io
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, UploadFile
from sqlmodel import Session, select

from database import Batch, Product, Sale, get_session
from schemas import RowError, SalesImportResult

router = APIRouter(prefix="/sales", tags=["sales"])

REQUIRED_COLUMNS = {"date", "product_id", "quantity"}


def consume_fifo(session: Session, product_id: int, quantity: float):
    """Take sold quantity out of active batches, soonest-expiring first."""
    batches = session.exec(select(Batch)
                           .where(Batch.product_id == product_id, Batch.status == "active")
                           .order_by(Batch.expiry_date))
    for batch in batches:
        if quantity <= 0:
            break
        taken = min(batch.quantity, quantity)
        batch.quantity -= taken
        quantity -= taken
        if batch.quantity <= 0:
            batch.status = "sold_out"


@router.post("/import", response_model=SalesImportResult)
async def import_sales(file: UploadFile, session: Session = Depends(get_session)):
    """Import a POS export CSV with columns date (YYYY-MM-DD), product_id, quantity.

    Good rows are saved and taken out of stock; bad rows are skipped and reported back.
    """
    reader = csv.DictReader(io.StringIO((await file.read()).decode("utf-8-sig")))
    missing = REQUIRED_COLUMNS - set(reader.fieldnames or [])
    if missing:
        raise HTTPException(400, f"Missing columns: {', '.join(sorted(missing))}")

    known = set(session.exec(select(Product.product_id)))
    imported, rejected = 0, []
    for line, row in enumerate(reader, start=2):
        try:
            sale = Sale(product_id=int(row["product_id"]), sale_date=date.fromisoformat(row["date"]),
                        quantity=float(row["quantity"]))
        except (TypeError, ValueError) as e:
            rejected.append(RowError(row=line, error=str(e)))
            continue
        if sale.product_id not in known:
            rejected.append(RowError(row=line, error=f"Unknown product_id {sale.product_id}"))
        elif sale.quantity <= 0:
            rejected.append(RowError(row=line, error="quantity must be positive"))
        else:
            session.add(sale)
            consume_fifo(session, sale.product_id, sale.quantity)
            imported += 1
    session.commit()
    return SalesImportResult(rows_imported=imported, rows_rejected=rejected)
