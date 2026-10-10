"""Policies the simulator compares. Each gets one day's view and returns rows of
store_id, product_id, discount_pct (a store-SKU left out gets no discount).

    batches:    store_id, product_id, batch_id, quantity, received_date, expiry_date
                (expiry_date is the last sellable day)
    today:      pd.Timestamp
    forecasts:  forecasts made yesterday (horizon 1 = today), never the true demand
    sku_params, elasticity: as in out/
"""
import pandas as pd

KEYS = ["store_id", "product_id"]
NO_ACTION = pd.DataFrame({"store_id": [], "product_id": [], "discount_pct": []})


def days_left(batches, today):
    """Sellable days left, counting today and the expiry day."""
    return (pd.to_datetime(batches["expiry_date"]) - today).dt.days + 1


def b1_do_nothing(batches, today, forecasts, sku_params, elasticity):
    return NO_ACTION


def b2_last_day(batches, today, forecasts, sku_params, elasticity):
    """30% off the SKU when any batch is on its last sellable day."""
    hit = batches[days_left(batches, today) <= 1]
    return hit[KEYS].drop_duplicates().assign(discount_pct=30)


def b3_ma_rule(batches, today, forecasts, sku_params, elasticity):
    """20% off when stock exceeds the 7-day average demand x days left on the oldest batch."""
    if batches.empty:
        return NO_ACTION
    per_sku = (batches.assign(left=days_left(batches, today))
               .groupby(KEYS).agg(stock=("quantity", "sum"), left=("left", "min")).reset_index())
    ma = forecasts.loc[forecasts["horizon"] == 1, KEYS + ["q50"]]
    per_sku = per_sku.merge(ma, on=KEYS, how="left")
    hit = per_sku[per_sku["stock"] > per_sku["q50"].fillna(0) * per_sku["left"]]
    return hit[KEYS].assign(discount_pct=20)
