from sqlmodel import Session, select
from fastapi import APIRouter, Depends

from database import Batch, Product, get_session
from schemas import ProductOut, StockItem

router = APIRouter(tags=["stock"])


@router.get("/products", response_model=list[ProductOut])
def list_products(session: Session = Depends(get_session)):
    return session.exec(select(Product).order_by(Product.category, Product.name)).all()


@router.get("/stock", response_model=list[StockItem])
def list_stock(session: Session = Depends(get_session)):
    """Every product with its total stock across active batches, including products with none."""
    stock = {
        p.product_id: StockItem(product_id=p.product_id, name=p.name, category=p.category, unit=p.unit,
                                quantity=0, active_batches=0, next_expiry=None)
        for p in session.exec(select(Product).order_by(Product.category, Product.name))
    }
    for batch in session.exec(select(Batch).where(Batch.status == "active")):
        item = stock[batch.product_id]
        item.quantity += batch.quantity
        item.active_batches += 1
        if item.next_expiry is None or batch.expiry_date < item.next_expiry:
            item.next_expiry = batch.expiry_date
    return list(stock.values())
