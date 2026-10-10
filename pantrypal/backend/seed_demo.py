"""Fill the database with a believable week for the demo: stock batches and recent sales for the app's store.

Run from this folder:
    python seed_demo.py                         # demo date 2024-06-20
    python seed_demo.py --date 2024-05-15 --reset
    python seed_demo.py --pos-export            # only rewrite data/sample_pos_export.csv

Quantities follow the ML forecast for each product, so the alerts on the demo date are realistic.
Start the server on the same date so it agrees (PowerShell): $env:PANTRYPAL_TODAY = "2024-06-20"
"""
import argparse
import csv
from datetime import date, timedelta
from itertools import islice
from pathlib import Path

import numpy as np
import pandas as pd
from sqlmodel import Session, delete, select

import database
from database import Batch, Product, Sale, SalesImport, init_db
from services.alert_service import STORE_ID, ml_forecasts

DEFAULT_DATE = date(2024, 6, 20)
HISTORY_DAYS = 7
SEED = 42
ROLES = {"expired": 2, "slow": 8, "on_track": 4}  # how many products get each kind of older batch
POS_EXPORT = Path(__file__).resolve().parent.parent / "data" / "sample_pos_export.csv"


def daily_demand(day: date) -> dict:
    """{product_id: median forecast demand on `day`} from the forecast made the day before."""
    f = ml_forecasts()
    f = f[(f["origin_date"] == pd.Timestamp(day - timedelta(days=1))) & (f["target_date"] == pd.Timestamp(day))]
    return dict(zip(f["product_id"], f["q50"]))


def seed(session: Session, day: date, random_seed: int = SEED) -> tuple[int, int]:
    """Replace all batches, sales and import history with demo data as of `day`. Returns (batches, sales) added."""
    demand = daily_demand(day)
    if not demand:
        raise SystemExit(f"No ML forecast for {day}. Pick a date inside ml/out/forecasts.csv.")
    session.exec(delete(SalesImport))
    session.exec(delete(Sale))
    session.exec(delete(Batch))
    rng = np.random.default_rng(random_seed)

    # Last week's sales: what the forecast expected each day.
    sales = 0
    for back in range(1, HISTORY_DAYS + 1):
        sale_day = day - timedelta(days=back)
        for product_id, quantity in daily_demand(sale_day).items():
            session.add(Sale(product_id=int(product_id), sale_date=sale_day, quantity=round(quantity, 1)))
            sales += 1

    # Every product gets a fresh delivery today, sized to sell out. A few also have an older batch:
    # EXPIRED products have leftovers from yesterday, SLOW ones have far more than will sell before it
    # expires in 0-2 days, and ON_TRACK ones have an older batch that should just sell out in time.
    products = session.exec(select(Product)).all()
    order = iter(rng.permutation(len(products)))
    roles = {products[i].product_id: role for role, count in ROLES.items() for i in islice(order, count)}
    batches = 0
    for product in products:
        per_day, shelf = demand.get(product.product_id, 0), product.shelf_life_days
        stock = [(day, per_day * shelf * 0.7)]
        role = roles.get(product.product_id)
        if role == "expired":  # last sellable day was yesterday
            stock.append((day - timedelta(days=shelf), per_day * rng.uniform(0.3, 0.8)))
        elif role in ("slow", "on_track"):
            days_left = int(rng.integers(0, min(shelf - 1, 3)))
            factor = rng.uniform(1.3, 2.0) if role == "slow" else rng.uniform(0.4, 0.7)
            stock.append((day + timedelta(days=days_left - shelf + 1), per_day * (days_left + 1) * factor))
        for received, quantity in stock:
            # The day a batch arrives is day 1 of its shelf life, as in the ML backtest.
            session.add(Batch(product_id=product.product_id, quantity=max(round(quantity, 1), 1.0),
                              received_date=received, expiry_date=received + timedelta(days=shelf - 1)))
            batches += 1
    session.commit()
    return batches, sales


def write_pos_export(day: date, path: Path = POS_EXPORT) -> int:
    """Write `day`'s sales as a POS export for /sales/import, plus two bad rows to show the validation.
    Returns the number of rows written."""
    demand = daily_demand(day)
    if not demand:
        raise SystemExit(f"No ML forecast for {day}. Pick a date inside ml/out/forecasts.csv.")
    names = pd.read_csv(database.CATALOG_CSV).set_index("product_id")["name"]
    stamp = f"{day:%d/%m/%Y}"
    rows = sorted((stamp, names[product_id], round(quantity, 1)) for product_id, quantity in demand.items())
    rows += [(stamp, "Strawberries 250g", 6), (f"32/{day:%m/%Y}", "Greek Yogurt", 9)]
    with open(path, "w", newline="") as f:
        writer = csv.writer(f, lineterminator="\n")
        writer.writerow(["date", "product", "quantity"])
        writer.writerows(rows)
    return len(rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--date", type=date.fromisoformat, default=DEFAULT_DATE, help="demo date, YYYY-MM-DD")
    parser.add_argument("--reset", action="store_true", help="replace the stock and sales already in the database")
    parser.add_argument("--pos-export", action="store_true",
                        help=f"only write {POS_EXPORT.name} with the sales of --date, and leave the database alone")
    args = parser.parse_args()

    if args.pos_export:
        print(f"Wrote {write_pos_export(args.date)} rows to {POS_EXPORT}")
        return

    init_db()
    with Session(database.engine) as session:
        if session.exec(select(Batch)).first() and not args.reset:
            raise SystemExit("The database already has stock. Rerun with --reset to replace it.")
        batches, sales = seed(session, args.date)
    print(f"Store {STORE_ID} as of {args.date}: {batches} batches, {sales} sales rows over {HISTORY_DAYS} days.")
    print(f'Start the server on the same date: $env:PANTRYPAL_TODAY = "{args.date}"')


if __name__ == "__main__":
    main()
