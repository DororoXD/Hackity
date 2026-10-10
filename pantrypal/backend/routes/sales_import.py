import csv
import io
from datetime import date, datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, UploadFile
from sqlmodel import Session, select

import clock
from database import Batch, Product, Sale, SalesImport, get_session
from schemas import ImportRecord, ImportRow, RowStatus, SalesImportResult

router = APIRouter(prefix="/sales", tags=["sales"])

DATE_FORMATS = ("%Y-%m-%d", "%d/%m/%Y")  # 2024-06-20 or 20/06/2024
NOT_CSV = "Only CSV files can be imported. In Excel, use File > Save As > CSV."


def consume_fifo(session: Session, product_id: int, quantity: float, sale_date: date):
    """Take sold quantity out of the batches on the shelf that day, soonest-expiring first."""
    batches = session.exec(select(Batch)
                           .where(Batch.product_id == product_id, Batch.status == "active",
                                  Batch.received_date <= sale_date, Batch.expiry_date >= sale_date)
                           .order_by(Batch.expiry_date))
    for batch in batches:
        if quantity <= 0:
            break
        taken = min(batch.quantity, quantity)
        batch.quantity -= taken
        quantity -= taken
        if batch.quantity <= 0:
            batch.status = "sold_out"


def read_csv_text(data: bytes) -> str:
    """The upload as text. Excel and other binary files are refused with a 400, not a crash."""
    if data.startswith((b"PK\x03\x04", b"\xd0\xcf\x11\xe0")) or b"\x00" in data:  # .xlsx, .xls, binary
        raise HTTPException(400, NOT_CSV)
    try:
        return data.decode("utf-8-sig")
    except UnicodeDecodeError:
        pass
    try:
        return data.decode("cp1252")  # what Excel on Windows writes for "CSV (Comma delimited)"
    except UnicodeDecodeError:
        raise HTTPException(400, NOT_CSV)


def parse_date(text: str) -> Optional[date]:
    for fmt in DATE_FORMATS:
        try:
            return datetime.strptime(text, fmt).date()
        except ValueError:
            pass
    return None


def parse_quantity(text: str) -> Optional[float]:
    try:
        quantity = float(text)
    except ValueError:
        return None
    return quantity if quantity > 0 else None


@router.post("/import", response_model=SalesImportResult)
async def import_sales(file: UploadFile, date_column: str = "date", product_column: str = "product",
                       quantity_column: str = "quantity", dry_run: bool = False,
                       session: Session = Depends(get_session)):
    """Import a POS export CSV. Every row comes back with a status, and only "ok" rows are saved.

    The product column can hold product names (any case) or product IDs. Dates can be YYYY-MM-DD or
    DD/MM/YYYY. Name the columns with the *_column parameters when the file's headers differ (the app's
    Map step); spaces and capitals in column names don't matter. Use dry_run=true to preview without
    saving. Saved sales come out of stock, soonest-expiring batch first.
    """
    reader = csv.DictReader(io.StringIO(read_csv_text(await file.read())))
    reader.fieldnames = [h.strip() for h in reader.fieldnames or []]
    headers = {h.lower(): h for h in reader.fieldnames}
    missing = [c for c in (date_column, product_column, quantity_column) if c.strip().lower() not in headers]
    if missing:
        quoted = lambda names: ", ".join(f'"{n}"' for n in names)
        raise HTTPException(400, f"Column not found: {quoted(missing)}. The file has: {quoted(reader.fieldnames)}")
    date_column, product_column, quantity_column = (
        headers[c.strip().lower()] for c in (date_column, product_column, quantity_column))

    products = session.exec(select(Product)).all()
    lookup = {p.name.lower(): p for p in products} | {str(p.product_id): p for p in products}
    rows = []
    for line, raw in enumerate(reader, start=2):
        product_text = (raw[product_column] or "").strip()
        sale_date = parse_date((raw[date_column] or "").strip())
        quantity = parse_quantity((raw[quantity_column] or "").strip())
        product = lookup.get(product_text.lower())
        status = (RowStatus.bad_date if sale_date is None else
                  RowStatus.bad_quantity if quantity is None else
                  RowStatus.unmatched if product is None else RowStatus.ok)
        rows.append(ImportRow(row=line, sale_date=sale_date, product=product_text, quantity=quantity, status=status,
                              product_id=product.product_id if product else None,
                              name=product.name if product else None))

    ok = [r for r in rows if r.status == RowStatus.ok]
    if not dry_run:
        for r in ok:
            session.add(Sale(product_id=r.product_id, sale_date=r.sale_date, quantity=r.quantity))
            consume_fifo(session, r.product_id, r.quantity, r.sale_date)
        session.add(SalesImport(filename=file.filename or "upload.csv", imported_on=clock.today(),
                                rows_imported=len(ok), rows_rejected=len(rows) - len(ok)))
        session.commit()
    unmatched = sum(r.status == RowStatus.unmatched for r in rows)
    return SalesImportResult(rows=rows, ok=len(ok), unmatched=unmatched, errors=len(rows) - len(ok) - unmatched,
                             imported=0 if dry_run else len(ok))


@router.get("/imports", response_model=list[ImportRecord])
def list_imports(limit: int = 10, session: Session = Depends(get_session)):
    """The most recent imports first, for the import history list."""
    return session.exec(select(SalesImport).order_by(SalesImport.id.desc()).limit(limit)).all()
