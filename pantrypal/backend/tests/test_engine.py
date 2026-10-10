from pathlib import Path

import pandas as pd

from engine import OUTPUT_COLUMNS, recommend

TODAY = "2024-06-10"
SKUS = pd.DataFrame({"product_id": [41], "price": [7.0], "name": ["Tomatoes"], "unit": ["kg"]})
NO_ELASTICITY = pd.DataFrame(columns=["first_category_id", "discount_pct", "sales_multiplier"])


def lifts(**multipliers):
    """Elasticity rows for Tomatoes' category (4), e.g. lifts(d20=1.3) for x1.3 sales at 20% off."""
    return pd.DataFrame([{"first_category_id": 4, "discount_pct": int(k[1:]), "sales_multiplier": v}
                         for k, v in multipliers.items()])


def forecasts(q50, q10=None, q90=None, origin="2024-06-09", store_id=1, product_id=41):
    """Forecast rows for today, tomorrow and the day after, all made at `origin`."""
    q10, q90 = q10 if q10 is not None else q50, q90 if q90 is not None else q50
    targets = pd.date_range(TODAY, periods=3)
    return pd.DataFrame({"store_id": store_id, "product_id": product_id, "origin_date": origin,
                         "target_date": targets, "horizon": range(1, 4), "q10": q10, "q50": q50, "q90": q90})


def batches(*rows):
    """rows of (batch_id, quantity, expiry_date) for Tomatoes in store 1."""
    return pd.DataFrame([{"store_id": 1, "product_id": 41, "batch_id": b, "quantity": q, "expiry_date": e}
                         for b, q, e in rows])


def test_expired_batch_is_removed():
    out = recommend(batches((1, 4, "2024-06-08")), forecasts(5), SKUS, NO_ELASTICITY, TODAY)
    assert list(out.columns) == OUTPUT_COLUMNS
    row = out.iloc[0]
    assert (row.issue_type, row.action, row.risk, row.expected_waste_units, row.rm_at_risk) == \
        ("expired", "remove", 1.0, 4.0, 28.0)


def test_batch_that_will_sell_out_is_not_reported():
    # 3 days x 5 kg demand covers 12 kg.
    out = recommend(batches((1, 12, "2024-06-12")), forecasts(5), SKUS, NO_ELASTICITY, TODAY)
    assert out.empty


def test_batches_outside_the_window_are_ignored():
    out = recommend(batches((1, 100, "2024-06-13")), forecasts(1), SKUS, NO_ELASTICITY, TODAY)
    assert out.empty


def test_slow_batch_gets_a_discount_that_pays_off():
    # 3 days x 2 kg = 6 kg of 12 kg sells at full price: 6 kg wasted, RM42 at risk.
    out = recommend(batches((7, 12, "2024-06-12")), forecasts(2), SKUS, lifts(d10=1.2, d20=1.8, d30=2.0), TODAY)
    row = out.iloc[0]
    assert (row.batch_id, row.issue_type, row.action, row.risk) == (7, "expiring_soon", "discount", 1.0)
    assert (row.expected_waste_units, row.rm_at_risk) == (6.0, 42.0)
    # 20% off: 6 kg x 1.8 = 10.8 kg sold at RM5.60 = RM60.48, versus 6 kg at RM7 = RM42.
    assert (row.discount_pct, row.expected_rm_saved) == (20, 18.48)
    assert row.explanation.startswith("12 kg Tomatoes expire in 2 days. About 6.0 kg is expected to sell")


def test_no_discount_when_demand_does_not_respond():
    out = recommend(batches((7, 12, "2024-06-12")), forecasts(2), SKUS, lifts(d10=1.0, d20=1.0), TODAY)
    assert (out.iloc[0].action, out.iloc[0].discount_pct, out.iloc[0].expected_rm_saved) == ("monitor", 0, 0.0)


def test_last_day_with_no_demand_means_donate():
    out = recommend(batches((7, 5, TODAY)), forecasts(0), SKUS, NO_ELASTICITY, TODAY)
    assert (out.iloc[0].action, out.iloc[0].expected_waste_units) == ("donate", 5.0)


def test_soonest_expiring_batch_sells_first():
    # 3 days x 5 kg = 15 kg demand. The 10 kg batch expiring today takes 5 kg, so the 12 kg batch
    # expiring in 2 days sees 10 kg of demand: the old batch wastes 5 kg, the new one 2 kg.
    out = recommend(batches((1, 10, TODAY), (2, 12, "2024-06-12")), forecasts(5), SKUS, NO_ELASTICITY, TODAY)
    waste = dict(zip(out.batch_id, out.expected_waste_units))
    assert waste == {1: 5.0, 2: 2.0}


def test_risk_comes_from_the_forecast_range():
    # Median demand sells everything, but in the low-demand scenarios some is left over.
    out = recommend(batches((1, 12, "2024-06-12")), forecasts(q50=4, q10=1, q90=7), SKUS, NO_ELASTICITY, TODAY)
    row = out.iloc[0]
    assert 0.2 <= row.risk < 1 and 0 < row.expected_waste_units < 12


def test_ignores_forecasts_made_today_or_later():
    leaky = pd.concat([forecasts(2), forecasts(100, origin=TODAY)])
    out = recommend(batches((7, 12, "2024-06-12")), leaky, SKUS, NO_ELASTICITY, TODAY)
    assert out.iloc[0].expected_waste_units == 6.0


def test_stores_are_kept_apart():
    two_stores = pd.concat([forecasts(2, store_id=1), forecasts(10, store_id=2)])
    b = pd.concat([batches((1, 12, "2024-06-12")), batches((2, 12, "2024-06-12")).assign(store_id=2)])
    out = recommend(b, two_stores, SKUS, NO_ELASTICITY, TODAY)
    assert list(out.store_id) == [1]


def test_reads_the_ml_output_files():
    ml_out = Path(__file__).resolve().parents[2] / "ml" / "out"
    sku_params, elasticity = pd.read_csv(ml_out / "sku_params.csv"), pd.read_csv(ml_out / "elasticity.csv")
    out = recommend(batches((7, 12, "2024-06-12")), forecasts(2), sku_params, elasticity, TODAY)
    row = out.iloc[0]
    assert row.action == "discount" and row.discount_pct in set(elasticity.discount_pct)
    assert row.explanation.startswith("12 units Tomatoes expire in 2 days")
