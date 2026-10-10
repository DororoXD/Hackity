"""Decision engine: which batches are at risk of going to waste, and what to do about them.

Plain pandas/numpy, no database, so the API and the ML backtest run the same code:
    import sys; sys.path.insert(0, "<repo>/pantrypal/backend")
    from engine import recommend

Inputs (extra columns are ignored):
    batches     store_id, product_id, batch_id, quantity, expiry_date (last day the batch can be sold)
    forecasts   store_id, product_id, origin_date, target_date, q10, q50, q90   (ml/out/forecasts.csv)
    sku_params  product_id, price, and optionally name, unit, first_category_id (ml/out/sku_params.csv)
    elasticity  first_category_id, discount_pct, sales_multiplier              (ml/out/elasticity.csv)
Missing first_category_id and name columns are filled from data/product_catalog.csv.
"""
from pathlib import Path

import numpy as np
import pandas as pd

CATALOG_CSV = Path(__file__).resolve().parent.parent / "data" / "product_catalog.csv"

WINDOW_DAYS = 2  # only look at batches whose last sellable day is within this many days
RISK_THRESHOLD = 0.2  # report a batch when the chance some of it goes unsold is at least this
DEFAULT_LIFT_PER_PCT = 0.015  # +1.5% sales per 1% off, for discounts missing from the elasticity table
DEFAULT_DISCOUNT_LEVELS = (10, 20, 30)  # used when the elasticity table is empty
QUANTILE_GRID = np.round(np.arange(0.05, 1.0, 0.05), 2)  # demand scenarios behind risk and expected waste

OUTPUT_COLUMNS = ["store_id", "product_id", "batch_id", "issue_type", "action", "discount_pct", "risk",
                  "expected_waste_units", "rm_at_risk", "expected_rm_saved", "explanation"]


def recommend(batches, forecasts, sku_params, elasticity, today, window_days=WINDOW_DAYS,
              risk_threshold=RISK_THRESHOLD):
    """One row per at-risk batch (OUTPUT_COLUMNS), biggest RM at risk first.

    Expired batches are always reported. A batch expiring within `window_days` is reported when its risk
    (the chance some of it is still unsold after its expiry day) is at least `risk_threshold`.
    Demand for each day comes from the latest forecast made before `today`, so nothing from today or
    later leaks in. Sales go to the soonest-expiring batch first. A discount is a sticker on this batch
    only; the engine tries each discount in the elasticity table, picks the one that earns the most from
    the batch, and reports how much more that earns than no discount as expected_rm_saved.
    rm_at_risk is the expected waste valued at the normal price.
    """
    today = pd.Timestamp(today).normalize()
    batches = batches.assign(expiry_date=pd.to_datetime(batches["expiry_date"]).dt.normalize())
    batches["days_left"] = (batches["expiry_date"] - today).dt.days
    batches = batches[batches["days_left"] <= window_days]
    if batches.empty:
        return pd.DataFrame(columns=OUTPUT_COLUMNS)

    demand = _daily_demand(forecasts, today, window_days)
    skus = _with_catalog(sku_params).set_index("product_id")
    lifts = _lift_table(elasticity)

    rows = []
    for (store_id, product_id), group in batches.groupby(["store_id", "product_id"]):
        sku = skus.loc[product_id]
        name, unit = sku.get("name", f"product {product_id}"), sku.get("unit", "units")
        price = float(sku["price"])
        discounts = lifts.get(sku["first_category_id"],
                              {d: 1 + DEFAULT_LIFT_PER_PCT * d for d in DEFAULT_DISCOUNT_LEVELS})
        quantiles = demand.get((store_id, product_id))
        group = group.sort_values(["expiry_date", "batch_id"])

        for i, batch in enumerate(group.itertuples()):
            qty = float(batch.quantity)
            if qty <= 0:
                continue
            what = f"{qty:g} {unit} {name}"
            if batch.days_left < 0:
                rows.append(dict(
                    store_id=store_id, product_id=product_id, batch_id=batch.batch_id, issue_type="expired",
                    action="remove", discount_pct=0, risk=1.0, expected_waste_units=qty,
                    rm_at_risk=qty * price, expected_rm_saved=0.0,
                    explanation=f"{what} expired {-batch.days_left} day(s) ago. "
                                f"Remove it from the shelf and record it as waste."))
                continue

            days = batch.days_left + 1  # today through the expiry day
            scenarios = _scenarios(quantiles, days)
            earlier = group.iloc[:i]
            earlier = earlier[earlier["days_left"] >= 0]
            outcomes = {d: _sell(scenarios, qty, earlier, lift) for d, lift in {0: 1.0, **discounts}.items()}

            sold0, waste0 = outcomes[0]
            risk = float((waste0 > 1e-9).mean())
            if risk < risk_threshold:
                continue
            revenue = {d: float(sold.mean()) * price * (1 - d / 100) for d, (sold, _) in outcomes.items()}
            best = max(revenue, key=lambda d: (round(revenue[d], 6), -d))
            saved = revenue[best] - revenue[0]
            expected_waste = float(waste0.mean())

            if best > 0 and saved > 0:
                action = "discount"
                extra = float(outcomes[best][0].mean() - sold0.mean())
                advice = (f"A {best}% discount should sell about {extra:.1f} {unit} more "
                          f"and recover about RM{saved:.2f}.")
            elif batch.days_left == 0:
                action, best, saved = "donate", 0, 0.0
                advice = "A discount would not sell enough today; donate what is left before closing."
            else:
                action, best, saved = "monitor", 0, 0.0
                advice = "No discount pays off yet; check again tomorrow."
            when = {0: "today", 1: "tomorrow"}.get(batch.days_left, f"in {batch.days_left} days")
            demand_note = ("There is no demand forecast for it" if quantiles is None else
                           f"About {float(sold0.mean()):.1f} {unit} is expected to sell by then")
            rows.append(dict(
                store_id=store_id, product_id=product_id, batch_id=batch.batch_id,
                issue_type="expiring_soon", action=action, discount_pct=best, risk=risk,
                expected_waste_units=expected_waste, rm_at_risk=expected_waste * price,
                expected_rm_saved=saved,
                explanation=f"{what} expire {when}. {demand_note}, so about {expected_waste:.1f} {unit} "
                            f"may go unsold ({risk:.0%} risk). {advice}"))

    out = pd.DataFrame(rows, columns=OUTPUT_COLUMNS)
    for col in ["risk", "expected_waste_units", "rm_at_risk", "expected_rm_saved"]:
        out[col] = out[col].astype(float).round(2)
    return out.sort_values("rm_at_risk", ascending=False, ignore_index=True)


def _with_catalog(sku_params):
    missing = [c for c in ("first_category_id", "name") if c not in sku_params.columns]
    if not missing:
        return sku_params
    catalog = pd.read_csv(CATALOG_CSV, usecols=["product_id", *missing])
    return sku_params.merge(catalog, on="product_id", how="left")


def _lift_table(elasticity):
    """{first_category_id: {discount_pct: sales_multiplier}}"""
    return {cat: dict(zip(g["discount_pct"].astype(int), g["sales_multiplier"].astype(float)))
            for cat, g in elasticity.groupby("first_category_id")}


def _daily_demand(forecasts, today, window_days):
    """{(store_id, product_id): array of (q10, q50, q90) for today, tomorrow, ...} from the latest
    forecast origin before today."""
    f = forecasts.assign(origin_date=pd.to_datetime(forecasts["origin_date"]),
                         target_date=pd.to_datetime(forecasts["target_date"]))
    f = f[(f["origin_date"] < today) & (f["target_date"] >= today)
          & (f["target_date"] <= today + pd.Timedelta(days=window_days))]
    f = f[f["origin_date"] == f.groupby(["store_id", "product_id"])["origin_date"].transform("max")]
    f = f.assign(day=(f["target_date"] - today).dt.days)
    return {key: g.sort_values("day")[["q10", "q50", "q90"]].to_numpy(dtype=float)
            for key, g in f.groupby(["store_id", "product_id"])}


def _scenarios(quantiles, days):
    """Demand per scenario and day, shape (len(QUANTILE_GRID), days). Scenario k uses the
    QUANTILE_GRID[k] quantile on every day. Days past the last forecast repeat it."""
    if quantiles is None:
        return np.zeros((len(QUANTILE_GRID), days))
    q = quantiles[np.minimum(np.arange(days), len(quantiles) - 1)]
    q10, q50, q90 = q[:, 0], q[:, 1], q[:, 2]
    p = QUANTILE_GRID[:, None]
    # Straight lines through (0.1, q10), (0.5, q50), (0.9, q90), extended past both ends.
    low = q50 + (p - 0.5) * (q50 - q10) / 0.4
    high = q50 + (p - 0.5) * (q90 - q50) / 0.4
    return np.clip(np.where(p < 0.5, low, high), 0, None)


def _sell(scenarios, qty, earlier, lift):
    """Units of this batch sold, and left over after its expiry day, per scenario.

    Each day's demand goes to earlier-expiring batches first at the normal price, then to this batch,
    whose (discounted) price multiplies the demand it sees by `lift`.
    """
    n, days = scenarios.shape
    stock = np.full(n, qty)
    earlier_stock = [np.full(n, float(q)) for q in earlier["quantity"]]
    earlier_last_day = list(earlier["days_left"])
    for t in range(days):
        remaining = scenarios[:, t].copy()
        for j, s in enumerate(earlier_stock):
            if earlier_last_day[j] >= t:
                taken = np.minimum(s, remaining)
                s -= taken
                remaining -= taken
        stock -= np.minimum(stock, remaining * lift)
    return qty - stock, stock
