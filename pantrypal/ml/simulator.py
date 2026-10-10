"""Step 5 of the ML runbook: the spoilage simulator. Frozen at the git tag sim-frozen.

Replays real stockout-corrected demand against invented deliveries and spoilage, so every
policy faces identical demand, identical batches and identical shelf-life luck. Only the
ordering and the spoilage are made up. After the freeze, change parameters only through
Settings inside the robustness tests, never in this file.

One simulated day:
1. Expire every batch whose age has reached its noisy shelf life; its units are waste.
2. Every 2nd day, deliver k x (mean demand of the last 14 days) x 2 days as one batch.
3. Show the policy the batches (with their printed expiry date) and yesterday's forecasts,
   never the true demand. It returns a discount per batch, like a markdown sticker.
4. Sell oldest stock first. A batch at d% off sells up to (demand still unmet) x the sales
   multiplier for d%, and each unit it sells uses up 1/multiplier of that demand, so the
   lift is extra demand and the rest goes on to the full-price batches behind it.
5. Unmet demand is lost.

Discounts were per store-SKU until just before the freeze; they became per batch to match
the engine and how shops mark stock down, before any engine results on real data were seen.

Run:  python simulator.py   (B1-B3 on the validation window, plus the runbook's checks)
"""
from dataclasses import dataclass

import numpy as np
import pandas as pd

from common import OUT_DIR, VAL, load_history

SEED = 2024
DELIVERY_EVERY = 2   # days between deliveries, at the start of the day
ORDER_DAYS = 2       # each order covers this many days of demand
ORDER_LOOKBACK = 14  # days of demand history behind each order
WARM_UP = 14         # days simulated before the metric window starts
KEYS = ["store_id", "product_id"]
LAST_DAY = 90


@dataclass(frozen=True)
class Settings:
    life_sigma: float = 0.15  # per-batch shelf-life noise, lognormal [Guessing]
    k_mean: float = 1.25      # order multiplier mean, lognormal [Guessing]
    k_sigma: float = 0.2
    life_shift: int = 0       # days added to every shelf life (robustness test 3)
    lift_scale: float = 1.0   # true lift = 1 + (multiplier - 1) x this (robustness test 4)


@dataclass
class Inputs:
    series: pd.DataFrame   # one row per store-SKU: keys, category, role, price, cost, shelf_life_days
    demand: np.ndarray     # [series, day] corrected demand in units; column 0 unused
    elasticity: pd.DataFrame
    day1: pd.Timestamp


@dataclass
class Result:
    daily: pd.DataFrame     # one row per store-SKU and day
    received: pd.DataFrame  # every batch delivered: batch_id, series, received_day, quantity
    expired: pd.DataFrame   # every batch that expired with stock left: batch_id, expired_day, expired_qty
    actions: pd.DataFrame   # the policy's raw output with a day column


def load_inputs():
    hist = load_history()
    if "demand" not in hist:
        raise SystemExit("No corrected demand: run stockout.py first")
    params = pd.read_csv(OUT_DIR / "sku_params.csv")
    hist["demand"] = hist["demand"] * params["unit_scale"].iloc[0]

    series = (hist[KEYS + ["first_category_id", "role"]].drop_duplicates(KEYS)
              .sort_values(KEYS).reset_index(drop=True)
              .merge(params[["product_id", "price", "cost", "shelf_life_days"]], on="product_id", how="left"))
    wide = (hist.pivot_table(index=KEYS, columns="day", values="demand")
            .reindex(pd.MultiIndex.from_frame(series[KEYS])).reindex(columns=range(1, LAST_DAY + 1)))
    demand = np.zeros((len(series), LAST_DAY + 1))
    demand[:, 1:] = wide.fillna(0).to_numpy()
    return Inputs(series, demand, pd.read_csv(OUT_DIR / "elasticity.csv"), hist["dt"].min())


def random_draws(inp, settings):
    """Order multiplier and shelf-life noise per series and delivery day. Seeded per store-SKU and
    drawn from the same standard normals under every Settings, so robustness runs share the luck."""
    n = len(inp.series)
    z_k, z_life = np.empty((n, LAST_DAY + 1)), np.empty((n, LAST_DAY + 1))
    for i, (store, product) in enumerate(zip(inp.series["store_id"], inp.series["product_id"])):
        rng = np.random.default_rng([SEED, int(store), int(product)])
        z_k[i], z_life[i] = rng.standard_normal(LAST_DAY + 1), rng.standard_normal(LAST_DAY + 1)
    mu = np.log(settings.k_mean) - settings.k_sigma ** 2 / 2
    return np.exp(mu + settings.k_sigma * z_k), np.exp(settings.life_sigma * z_life)


def sales_multiplier(inp, series_idx, discount_pct, lift_scale=1.0):
    """Sales multiplier for each (series, discount) pair, interpolated from elasticity.csv (0% off = x1)."""
    table = inp.elasticity.pivot_table(index="first_category_id", columns="discount_pct", values="sales_multiplier")
    depths = np.concatenate([[0.0], table.columns.to_numpy(dtype=float)])
    curves = np.column_stack([np.ones(len(table)), table.to_numpy()])
    rows = table.index.get_indexer(inp.series["first_category_id"].to_numpy()[series_idx])
    mult = np.ones(len(discount_pct))
    for i in np.flatnonzero(np.asarray(discount_pct) > 0):
        mult[i] = np.interp(discount_pct[i], depths, curves[rows[i]])
    return 1 + (mult - 1) * lift_scale


def simulate(policy, inp, start, end, forecasts=None, settings=Settings()):
    """Run `policy` on days start..end. forecasts: rows with an integer origin `day` column;
    the policy sees only those made yesterday (origin = day - 1), so horizon 1 is today."""
    assert start - ORDER_LOOKBACK >= 1, "not enough demand history before the first order"
    n, s = len(inp.series), inp.series
    k, life_noise = random_draws(inp, settings)
    shelf = s["shelf_life_days"].to_numpy() + settings.life_shift
    price, cost = s["price"].to_numpy(), s["cost"].to_numpy()
    by_origin = dict(tuple(forecasts.groupby("day"))) if forecasts is not None else {}
    no_forecast = forecasts.iloc[:0] if forecasts is not None else None

    batches = pd.DataFrame({"batch_id": pd.Series(dtype=str), "series": pd.Series(dtype=int),
                            "quantity": pd.Series(dtype=float), "received_day": pd.Series(dtype=int),
                            "life_days": pd.Series(dtype=int), "shelf_life_days": pd.Series(dtype=int)})
    daily, received, expired, actions = [], [], [], []

    for day in range(start, end + 1):
        # 1. expire
        gone = (day - batches["received_day"]) >= batches["life_days"]
        wasted = np.bincount(batches.loc[gone, "series"], batches.loc[gone, "quantity"], minlength=n)
        expired.append(batches.loc[gone, ["batch_id", "quantity"]]
                       .rename(columns={"quantity": "expired_qty"}).assign(expired_day=day))
        batches = batches[~gone]

        # 2. deliver
        got = np.zeros(n)
        if (day - start) % DELIVERY_EVERY == 0:
            got = k[:, day] * inp.demand[:, day - ORDER_LOOKBACK:day].mean(axis=1) * ORDER_DAYS
            new = pd.DataFrame({
                "batch_id": [f"{st}-{p}-{day}" for st, p in zip(s["store_id"], s["product_id"])],
                "series": np.arange(n), "quantity": got, "received_day": day,
                "life_days": np.maximum(1, np.round(shelf * life_noise[:, day])).astype(int),
                "shelf_life_days": shelf,
            })[got > 0]
            received.append(new[["batch_id", "series", "received_day", "quantity"]])
            batches = pd.concat([batches, new], ignore_index=True)

        # 3. ask the policy
        today = inp.day1 + pd.Timedelta(days=day - 1)
        received_date = inp.day1 + pd.to_timedelta(batches["received_day"] - 1, unit="D")
        view = pd.DataFrame({
            "store_id": s["store_id"].to_numpy()[batches["series"]],
            "product_id": s["product_id"].to_numpy()[batches["series"]],
            "batch_id": batches["batch_id"].to_numpy(), "quantity": batches["quantity"].to_numpy(),
            "received_date": received_date.to_numpy(),
            "expiry_date": (received_date + pd.to_timedelta(batches["shelf_life_days"] - 1, unit="D")).to_numpy(),
        })
        act = policy(view, today, by_origin.get(day - 1, no_forecast), s, inp.elasticity)
        batch_discount = np.zeros(len(batches))
        if len(act):
            actions.append(act.assign(day=day))
            asked = act.groupby("batch_id")["discount_pct"].max()  # the deepest discount asked for
            batch_discount = asked.reindex(batches["batch_id"]).fillna(0).to_numpy(dtype=float)

        # 4-5. sell oldest first; a discounted batch sells to the unmet demand x its multiplier
        order = np.lexsort((batches["received_day"].to_numpy(), batches["series"].to_numpy()))
        batches, batch_discount = batches.iloc[order].reset_index(drop=True), batch_discount[order]
        b_series = batches["series"].to_numpy()
        stock = batches["quantity"].to_numpy(dtype=float)
        mult = sales_multiplier(inp, b_series, batch_discount, settings.lift_scale)
        rank = batches.groupby("series").cumcount().to_numpy()
        unmet = inp.demand[:, day].astype(float)
        sold_b = np.zeros(len(batches))
        for r in range(rank.max() + 1 if len(rank) else 0):
            at = np.flatnonzero(rank == r)  # at most one batch per series at each rank
            sold_b[at] = np.minimum(stock[at], unmet[b_series[at]] * mult[at])
            unmet[b_series[at]] -= sold_b[at] / mult[at]
        unmet = np.clip(unmet, 0, None)

        sold = np.bincount(b_series, sold_b, minlength=n)
        b_price = price[b_series]
        revenue = np.bincount(b_series, sold_b * b_price * (1 - batch_discount / 100), minlength=n)
        given = np.bincount(b_series, sold_b * b_price * batch_discount / 100, minlength=n)
        discounted = np.bincount(b_series, sold_b * (batch_discount > 0), minlength=n)
        deepest = np.zeros(n)
        np.maximum.at(deepest, b_series, batch_discount)
        batches = batches.assign(quantity=stock - sold_b)
        batches = batches[batches["quantity"] > 1e-9]

        daily.append(pd.DataFrame({
            "series": np.arange(n), "day": day, "received": got, "demand": inp.demand[:, day],
            "sold": sold, "lost": unmet, "wasted": wasted, "discount_pct": deepest,
            "discounted_units": discounted, "revenue": revenue, "discount_given": given,
        }))

    return Result(pd.concat(daily, ignore_index=True), pd.concat(received, ignore_index=True),
                  pd.concat(expired, ignore_index=True),
                  pd.concat(actions, ignore_index=True) if actions else pd.DataFrame())


def summarize(res, inp, days, role=None):
    """Money and waste over `days` (inclusive). Profit = revenue - cost of units sold or wasted,
    so stock carried into or out of the window is valued at cost and does not bias the comparison."""
    d = res.daily.merge(inp.series[["role", "price", "cost"]], left_on="series", right_index=True)
    d = d[d["day"].between(*days)]
    if role:
        d = d[d["role"] == role]
    revenue = d["revenue"].sum()
    return {
        "received_units": d["received"].sum(),
        "sold_units": d["sold"].sum(),
        "waste_units": d["wasted"].sum(),
        "waste_rm": (d["wasted"] * d["cost"]).sum(),
        "waste_pct": d["wasted"].sum() / max(d["received"].sum(), 1e-9),
        "discount_given_rm": d["discount_given"].sum(),
        "revenue_rm": revenue,
        "profit_rm": revenue - ((d["sold"] + d["wasted"]) * d["cost"]).sum(),
        "discounted_units": d["discounted_units"].sum(),
        "lost_sales_units": d["lost"].sum(),
    }


def assert_paired(a, b):
    """Pitfall 5: every policy must see the same batches (ids, days and quantities)."""
    cols = ["batch_id", "received_day", "quantity"]
    pd.testing.assert_frame_equal(a.received[cols].reset_index(drop=True), b.received[cols].reset_index(drop=True))


def ma7_for_policies(inp):
    """Moving-average forecasts on the simulator's demand (units), with an integer origin `day`."""
    from forecast_demand import add_quantiles, ma7_forecasts
    long = pd.DataFrame({
        "store_id": np.repeat(inp.series["store_id"].to_numpy(), LAST_DAY),
        "product_id": np.repeat(inp.series["product_id"].to_numpy(), LAST_DAY),
        "first_category_id": np.repeat(inp.series["first_category_id"].to_numpy(), LAST_DAY),
        "role": np.repeat(inp.series["role"].to_numpy(), LAST_DAY),
        "day": np.tile(np.arange(1, LAST_DAY + 1), len(inp.series)),
        "demand": inp.demand[:, 1:].ravel(),
    })
    long["dt"] = inp.day1 + pd.to_timedelta(long["day"] - 1, unit="D")
    return add_quantiles(ma7_forecasts(long, "demand"))


def main():
    from policies import b1_do_nothing, b2_last_day, b3_ma_rule

    inp = load_inputs()
    ma7 = ma7_for_policies(inp)
    start, end = VAL[0] - WARM_UP, VAL[1]
    print(f"{len(inp.series)} series, simulating days {start}-{end}, metrics on validation days {VAL[0]}-{VAL[1]}, known stores")

    runs = {name: simulate(pol, inp, start, end, ma7) for name, pol in
            [("B1", b1_do_nothing), ("B2", b2_last_day), ("B3", b3_ma_rule)]}
    table = pd.DataFrame({name: summarize(r, inp, VAL, "known") for name, r in runs.items()}).T
    print(table.round(3).to_string())

    assert_paired(runs["B1"], runs["B2"])
    assert_paired(runs["B1"], runs["B3"])
    again = simulate(b1_do_nothing, inp, start, end, ma7)
    pd.testing.assert_frame_equal(runs["B1"].daily, again.daily)
    b1, b2 = table.loc["B1"], table.loc["B2"]
    print("checks: B1 wastes stock:", b1["waste_units"] > 0,
          "| B2 wastes less than B1:", b2["waste_units"] < b1["waste_units"],
          "| same batches for every policy: True | rerun identical: True")


if __name__ == "__main__":
    main()
