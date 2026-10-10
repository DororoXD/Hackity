"""Policies the simulator compares. Each gets one day's view and returns rows of
store_id, product_id, batch_id, discount_pct: a markdown on that batch only
(a batch left out stays at full price).

    batches:    store_id, product_id, batch_id, quantity, received_date, expiry_date
                (expiry_date is the last sellable day)
    today:      pd.Timestamp
    forecasts:  forecasts made yesterday (horizon 1 = today), never the true demand
    sku_params, elasticity: as in out/
"""
import pandas as pd

KEYS = ["store_id", "product_id"]
NO_ACTION = pd.DataFrame({"store_id": [], "product_id": [], "batch_id": [], "discount_pct": []})


def days_left(batches, today):
    """Sellable days left, counting today and the expiry day."""
    return (pd.to_datetime(batches["expiry_date"]) - today).dt.days + 1


def b1_do_nothing(batches, today, forecasts, sku_params, elasticity):
    return NO_ACTION


def b2_last_day(batches, today, forecasts, sku_params, elasticity):
    """30% off every batch on its last sellable day."""
    hit = batches[days_left(batches, today) <= 1]
    return hit[KEYS + ["batch_id"]].assign(discount_pct=30)


def b3_ma_rule(batches, today, forecasts, sku_params, elasticity):
    """20% off the oldest batch when the SKU's stock exceeds the 7-day average demand x the
    days left on that batch."""
    if batches.empty:
        return NO_ACTION
    b = batches.assign(left=days_left(batches, today)).sort_values(KEYS + ["expiry_date", "batch_id"])
    oldest = b.groupby(KEYS).head(1)[KEYS + ["batch_id", "left"]]
    stock = b.groupby(KEYS)["quantity"].sum().rename("stock").reset_index()
    ma = forecasts.loc[forecasts["horizon"] == 1, KEYS + ["q50"]]
    per_sku = oldest.merge(stock, on=KEYS).merge(ma, on=KEYS, how="left")
    hit = per_sku[per_sku["stock"] > per_sku["q50"].fillna(0) * per_sku["left"]]
    return hit[KEYS + ["batch_id"]].assign(discount_pct=20)
