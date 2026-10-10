"""Step 2 of the ML runbook: moving-average forecasts in the final forecasts.csv format.

q50 is the mean of the last 7 days of demand (stockout-corrected once stockout.py
has run, raw sales before that), origin day included. q10 and q90 scale q50 by the
10th and 90th percentiles of actual / q50, measured per first_category_id and horizon
on training-day targets of the known stores only. Quantities are rescaled by unit_scale.

Writes out/forecasts.csv (model = ma7). Run:  python forecast_demand.py
"""
import pandas as pd

from common import OUT_DIR, TRAIN, VAL, load_history, unit_scale

HORIZONS = (1, 2, 3)
KEYS = ["store_id", "product_id"]
OUT_COLS = ["store_id", "product_id", "origin_date", "target_date", "horizon", "q10", "q50", "q90", "model"]


def ma7_forecasts(df, col="sale_amount"):
    """One row per series, origin day and horizon, with q50 and the actual demand on the target day.

    Relies on every series having one row per day with no gaps (checked in step 1).
    """
    df = df.sort_values(KEYS + ["day"])
    g = df.groupby(KEYS)[col]
    base = df[KEYS + ["first_category_id", "role", "dt", "day"]].assign(
        q50=g.transform(lambda s: s.rolling(7, min_periods=7).mean()))
    fc = pd.concat([base.assign(horizon=h, actual=g.shift(-h)) for h in HORIZONS], ignore_index=True)
    fc = fc.dropna(subset=["q50"])
    fc["target_day"] = fc["day"] + fc["horizon"]
    fc["target_date"] = fc["dt"] + pd.to_timedelta(fc["horizon"], unit="D")
    return fc


def add_quantiles(fc):
    """q10/q90 from the spread of actual / q50 on training targets of known stores."""
    fit = fc[(fc["role"] == "known") & (fc["target_day"] <= TRAIN[1]) & (fc["q50"] > 0)]
    ratio = fit["actual"] / fit["q50"]
    by = [fit["first_category_id"], fit["horizon"]]
    r = pd.DataFrame({"r10": ratio.groupby(by).quantile(0.1), "r90": ratio.groupby(by).quantile(0.9)})
    fc = fc.merge(r, left_on=["first_category_id", "horizon"], right_index=True, how="left")
    fc["r10"] = fc["r10"].fillna(ratio.quantile(0.1))
    fc["r90"] = fc["r90"].fillna(ratio.quantile(0.9))
    fc["q10"] = (fc["q50"] * fc["r10"]).clip(upper=fc["q50"])
    fc["q90"] = (fc["q50"] * fc["r90"]).clip(lower=fc["q50"])
    return fc


def report(fc, days, label):
    """WAPE of q50, q10-q90 coverage and mean pinball loss on known stores' targets in `days`."""
    m = fc[(fc["role"] == "known") & fc["target_day"].between(*days)]
    wape = (m["actual"] - m["q50"]).abs().sum() / m["actual"].sum()
    coverage = m["actual"].between(m["q10"], m["q90"]).mean()
    pinball = sum(
        ((m["actual"] - m[q]) * (a - (m["actual"] < m[q]))).mean()
        for q, a in [("q10", 0.1), ("q50", 0.5), ("q90", 0.9)]
    ) / 3
    print(f"[{label}] ma7 WAPE {wape:.3f}, q10-q90 coverage {coverage:.1%}, pinball {pinball:.3f}, rows {len(m)}")


def main():
    hist = load_history()
    col = "demand" if "demand" in hist else "sale_amount"  # corrected demand once stockout.py has run
    scale = unit_scale(hist)
    hist[col] = hist[col] * scale
    print(f"unit_scale {scale:.4f} (multiply dataset sale_amount by this to get units)")
    print("target:", "stockout-corrected demand" if col == "demand" else "RAW sales - run stockout.py first")

    fc = add_quantiles(ma7_forecasts(hist, col))
    report(fc, VAL, "validation")  # never look at test numbers until the final run

    fc["origin_date"] = fc["dt"].dt.strftime("%Y-%m-%d")
    fc["target_date"] = fc["target_date"].dt.strftime("%Y-%m-%d")
    fc["model"] = "ma7"
    out = fc[OUT_COLS].sort_values(["store_id", "product_id", "origin_date", "horizon"]).round(3)
    out.to_csv(OUT_DIR / "forecasts.csv", index=False)
    print(f"wrote {len(out)} rows, origins {out['origin_date'].min()} .. {out['origin_date'].max()}")


if __name__ == "__main__":
    main()
