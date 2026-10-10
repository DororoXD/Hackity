from datetime import date, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select

from database import Batch, Product, get_session
from schemas import BatchCreate, BatchOut, BatchStatus, BatchUpdate

router = APIRouter(prefix="/batches", tags=["batches"])


def to_out(batch: Batch, product: Product, today: date) -> BatchOut:
    return BatchOut(
        id=batch.id, product_id=batch.product_id, name=product.name, unit=product.unit,
        quantity=batch.quantity, received_date=batch.received_date, expiry_date=batch.expiry_date,
        days_left=(batch.expiry_date - today).days, status=batch.status,
    )


@router.get("", response_model=list[BatchOut])
def list_batches(status: Optional[BatchStatus] = BatchStatus.active, today: Optional[date] = None,
                 session: Session = Depends(get_session)):
    """Batches soonest-expiring first. `today` overrides the date, for the simulator and demos."""
    query = select(Batch, Product).join(Product).order_by(Batch.expiry_date)
    if status:
        query = query.where(Batch.status == status.value)
    today = today or date.today()
    return [to_out(b, p, today) for b, p in session.exec(query)]


@router.post("", response_model=BatchOut, status_code=201)
def create_batch(body: BatchCreate, session: Session = Depends(get_session)):
    product = session.get(Product, body.product_id)
    if product is None:
        raise HTTPException(404, f"Unknown product_id {body.product_id}")
    received = body.received_date or date.today()
    batch = Batch(
        product_id=product.product_id, quantity=body.quantity, received_date=received,
        expiry_date=body.expiry_date or received + timedelta(days=product.shelf_life_days),
    )
    session.add(batch)
    session.commit()
    session.refresh(batch)
    return to_out(batch, product, date.today())


@router.patch("/{batch_id}", response_model=BatchOut)
def update_batch(batch_id: int, body: BatchUpdate, session: Session = Depends(get_session)):
    """Correct the remaining quantity, or mark the batch sold out or discarded."""
    batch = session.get(Batch, batch_id)
    if batch is None:
        raise HTTPException(404, f"Unknown batch {batch_id}")
    if body.quantity is not None:
        batch.quantity = body.quantity
    if body.status is not None:
        batch.status = body.status.value
    session.commit()
    session.refresh(batch)
    return to_out(batch, session.get(Product, batch.product_id), date.today())


@router.delete("/{batch_id}", status_code=204)
def delete_batch(batch_id: int, session: Session = Depends(get_session)):
    batch = session.get(Batch, batch_id)
    if batch is None:
        raise HTTPException(404, f"Unknown batch {batch_id}")
    session.delete(batch)
    session.commit()
