"""Today's alerts for the app: loads stock and sales from the DB and runs the decision engine on them.

Demand is the average daily sales over the last week until the ML forecasts are wired in.
Prices and discount response come from the ML team's files in ml/out/.
"""
from datetime import date, timedelta
from pathlib import Path

import pandas as pd
from sqlmodel import Session, func, select

from database import Batch, Product, Sale
from engine import WINDOW_DAYS, recommend
from schemas import Alert, Priority

ML_OUT = Path(__file__).resolve().parents[2] / "ml" / "out"
STORE_ID = 0  # the app manages a single store
SALES_LOOKBACK_DAYS = 7


def recent_sales_forecast(session: Session, product_ids, today: date) -> pd.DataFrame:
    """Forecast rows in the ML format, using last week's average daily sales for every day ahead."""
    since = today - timedelta(days=SALES_LOOKBACK_DAYS)
    totals = dict(session.exec(select(Sale.product_id, func.sum(Sale.quantity))
                               .where(Sale.sale_date >= since, Sale.sale_date < today)
                               .group_by(Sale.product_id)).all())
    rows = []
    for product_id in product_ids:
        daily = (totals.get(product_id) or 0) / SALES_LOOKBACK_DAYS
        for day in range(WINDOW_DAYS + 1):
            rows.append(dict(store_id=STORE_ID, product_id=product_id, origin_date=today - timedelta(days=1),
                             target_date=today + timedelta(days=day), q10=daily, q50=daily, q90=daily))
    return pd.DataFrame(rows)


def build_alerts(session: Session, today: date) -> list[Alert]:
    rows = session.exec(select(Batch, Product).join(Product).where(Batch.status == "active")).all()
    if not rows:
        return []
    batches = pd.DataFrame([dict(store_id=STORE_ID, product_id=b.product_id, batch_id=b.id,
                                 quantity=b.quantity, expiry_date=b.expiry_date) for b, _ in rows])
    products = {p.product_id: p for _, p in rows}
    names = pd.DataFrame([dict(product_id=p.product_id, name=p.name, unit=p.unit) for p in products.values()])
    sku_params = names.merge(pd.read_csv(ML_OUT / "sku_params.csv"), on="product_id")
    forecasts = recent_sales_forecast(session, products, today)
    elasticity = pd.read_csv(ML_OUT / "elasticity.csv")

    by_id = {b.id: (b, p) for b, p in rows}
    alerts = []
    for rec in recommend(batches, forecasts, sku_params, elasticity, today).itertuples():
        batch, product = by_id[rec.batch_id]
        days_left = (batch.expiry_date - today).days
        alerts.append(Alert(
            batch_id=batch.id, product_id=product.product_id, name=product.name, quantity=batch.quantity,
            unit=product.unit, days_left=days_left, priority=Priority.high if days_left <= 1 else Priority.medium,
            issue_type=rec.issue_type, action=rec.action, discount_pct=rec.discount_pct, risk=rec.risk,
            expected_waste_units=rec.expected_waste_units, rm_at_risk=rec.rm_at_risk,
            expected_rm_saved=rec.expected_rm_saved, explanation=rec.explanation,
        ))
    order = {Priority.high: 0, Priority.medium: 1, Priority.low: 2}
    return sorted(alerts, key=lambda a: (order[a.priority], -a.rm_at_risk))
