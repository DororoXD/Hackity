"""Turns stock and recent sales into today's alerts.

Rule-based for now: expected demand is the average daily sales over the last week.
Swap average_daily_sales for the ML forecast (ml/out/forecasts.csv, q50) once it is ready.
"""
from datetime import date, timedelta

from sqlmodel import Session, func, select

from database import Batch, Product, Sale
from schemas import Alert, IssueType, Priority

EXPIRY_WINDOW_DAYS = 2  # alert on batches whose last sellable day is within this many days
SALES_LOOKBACK_DAYS = 7


def average_daily_sales(session: Session, product_id: int, today: date) -> float:
    since = today - timedelta(days=SALES_LOOKBACK_DAYS)
    total = session.exec(select(func.sum(Sale.quantity))
                         .where(Sale.product_id == product_id, Sale.sale_date >= since,
                                Sale.sale_date < today)).one()
    return (total or 0) / SALES_LOOKBACK_DAYS


def when(days_left: int) -> str:
    return {0: "today", 1: "tomorrow"}.get(days_left, f"in {days_left} days")


def build_alerts(session: Session, today: date) -> list[Alert]:
    rows = session.exec(select(Batch, Product).join(Product)
                        .where(Batch.status == "active",
                               Batch.expiry_date <= today + timedelta(days=EXPIRY_WINDOW_DAYS)))
    alerts = []
    for batch, product in rows:
        days_left = (batch.expiry_date - today).days
        qty = f"{batch.quantity:g} {product.unit} {product.name}"
        common = dict(batch_id=batch.id, product_id=product.product_id, name=product.name,
                      quantity=batch.quantity, unit=product.unit, days_left=days_left)

        if days_left < 0:
            alerts.append(Alert(**common, issue_type=IssueType.expired, priority=Priority.high,
                                expected_unsold=batch.quantity,
                                message=f"{qty} expired {-days_left} day(s) ago.",
                                suggested_action="Remove from the shelf and record it as waste."))
            continue

        # Sellable days left include today and the expiry day itself.
        expected_sales = average_daily_sales(session, product.product_id, today) * (days_left + 1)
        unsold = round(max(0.0, batch.quantity - expected_sales), 1)
        if unsold == 0:
            continue  # on track to sell out in time
        alerts.append(Alert(**common, issue_type=IssueType.expiring_soon,
                            priority=Priority.high if days_left <= 1 else Priority.medium,
                            expected_unsold=unsold,
                            message=f"{qty} expire {when(days_left)}. About {unsold:g} {product.unit} "
                                    f"will likely go unsold at current sales.",
                            suggested_action="Discount now or donate before closing." if days_left == 0
                                             else "Discount it or move it to the front of the shelf."))

    order = {Priority.high: 0, Priority.medium: 1, Priority.low: 2}
    return sorted(alerts, key=lambda a: (order[a.priority], a.days_left, -a.expected_unsold))
