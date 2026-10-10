"""Step 8 of the ML runbook: run the backend's decision engine inside the frozen simulator.

"Ours" is backend/engine.py recommend(), fed the forecasts in out/forecasts.csv; B1-B3 use
the moving average. Every policy faces the same demand and batches (checked). Prints money,
waste, alerts per store per day, precision at 5 and a paired bootstrap interval of the profit
difference, then five alerts to hand-check against what happened under B1.

If recommend() cannot be imported, a stand-in rule runs instead (10% off a batch when the
median forecast will not clear it in time) and every result is labelled "stand-in engine".

Run:  python backtest.py   (validation days only; the test sets run once, in step 9)
"""
import sys

import numpy as np
import pandas as pd

from common import ML_DIR, OUT_DIR, VAL
from policies import b1_do_nothing, b2_last_day, b3_ma_rule, days_left
from simulator import WARM_UP, assert_paired, load_inputs, ma7_for_policies, simulate, summarize

KEYS = ["store_id", "product_id"]
BOOTSTRAP_DRAWS = 1000
SEED = 7

sys.path.append(str(ML_DIR.parent / "backend"))
try:
    from engine import recommend
    ENGINE = "engine"
except ImportError as err:
    print(f"WARNING: cannot import backend/engine.py ({err}); using the stand-in engine")
    recommend, ENGINE = None, "stand-in engine"


def stand_in(batches, forecasts, sku_params, elasticity, today):
    """10% off a batch when the median forecast over its days left will not clear the stock ahead of it."""
    if batches.empty:
        return pd.DataFrame()
    b = batches.assign(left=days_left(batches, today)).sort_values(KEYS + ["expiry_date", "batch_id"])
    b["through"] = b.groupby(KEYS)["quantity"].cumsum()
    f = forecasts[forecasts["horizon"] == 1][KEYS + ["q50"]]
    b = b.merge(f, on=KEYS, how="left")
    hit = b[b["through"] > b["q50"].fillna(0) * b["left"]]
    return hit[KEYS + ["batch_id"]].assign(discount_pct=10, action="discount", issue_type="expiring_soon",
                                           rm_at_risk=0.0, explanation="stand-in rule")


def engine_policy(sku_params):
    """Wrap recommend() as a simulator policy. Returns every alert; only discounts change prices."""
    def ours(batches, today, forecasts, _series, elasticity):
        if recommend is None:
            return stand_in(batches, forecasts, sku_params, elasticity, today)
        return recommend(batches, forecasts, sku_params, elasticity, today)
    return ours


def lgbm_for_policies(inp):
    """out/forecasts.csv with the integer origin `day` the simulator groups by."""
    f = pd.read_csv(OUT_DIR / "forecasts.csv")
    f["day"] = (pd.to_datetime(f["origin_date"]) - inp.day1).dt.days + 1
    return f


def per_series_profit(res, inp, days):
    d = res.daily[res.daily["day"].between(*days)].merge(
        inp.series[["cost"]], left_on="series", right_index=True)
    d["profit"] = d["revenue"] - (d["sold"] + d["wasted"]) * d["cost"]
    return d.groupby("series")["profit"].sum().reindex(range(len(inp.series)), fill_value=0).to_numpy()


def bootstrap(diff, rng):
    """95% interval of the total profit difference, resampling store-SKU series with replacement."""
    idx = rng.integers(0, len(diff), (BOOTSTRAP_DRAWS, len(diff)))
    totals = diff[idx].sum(axis=1)
    return np.percentile(totals, [2.5, 97.5])


def alert_quality(res_ours, res_b1, inp, days, role):
    """Alerts per store per day, and precision at 5: of each store-day's five predictive alerts
    with the most RM at risk, the share whose batch expires unsold under B1."""
    a = res_ours.actions
    if a.empty or "issue_type" not in a:
        return 0.0, float("nan")
    roles = inp.series.drop_duplicates("store_id").set_index("store_id")["role"]
    a = a[a["day"].between(*days) & (a["store_id"].map(roles) == role)]
    n_store_days = (roles == role).sum() * (days[1] - days[0] + 1)
    wasted_b1 = set(res_b1.expired.loc[res_b1.expired["expired_qty"] > 1e-9, "batch_id"])
    pred = a[a["issue_type"] == "expiring_soon"].sort_values("rm_at_risk", ascending=False)
    top5 = pred.groupby(["store_id", "day"]).head(5)
    precision = top5["batch_id"].isin(wasted_b1).mean() if len(top5) else float("nan")
    return len(a) / n_store_days, precision


def main():
    inp = load_inputs()
    sku_params = pd.read_csv(OUT_DIR / "sku_params.csv")
    ma7, ours_fc = ma7_for_policies(inp), lgbm_for_policies(inp)
    model = ours_fc["model"].iloc[0]
    start, end, role = VAL[0] - WARM_UP, VAL[1], "known"
    label = f"ours ({ENGINE}, {model} forecasts)"
    print(f"simulating days {start}-{end}; metrics on validation days {VAL[0]}-{VAL[1]}, {role} stores; {label}")

    runs = {"B1": simulate(b1_do_nothing, inp, start, end, ma7),
            "B2": simulate(b2_last_day, inp, start, end, ma7),
            "B3": simulate(b3_ma_rule, inp, start, end, ma7),
            "ours": simulate(engine_policy(sku_params), inp, start, end, ours_fc)}
    for name in ["B2", "B3", "ours"]:
        assert_paired(runs["B1"], runs[name])

    table = pd.DataFrame({k: summarize(r, inp, VAL, role) for k, r in runs.items()}).T
    print(table[["waste_pct", "waste_rm", "discount_given_rm", "revenue_rm", "profit_rm"]].round(3).to_string())

    known = (inp.series["role"] == role).to_numpy()
    n_stores = inp.series.loc[known, "store_id"].nunique()
    weeks = (VAL[1] - VAL[0] + 1) / 7
    profit = {k: per_series_profit(r, inp, VAL)[known] for k, r in runs.items()}
    rng = np.random.default_rng(SEED)
    rows = []
    print("\nnet saving of ours (simulated RM), paired bootstrap over store-SKU series:")
    for base in ["B1", "B2", "B3"]:
        diff = profit["ours"] - profit[base]
        lo, hi = bootstrap(diff, rng)
        verdict = "distinguishable" if lo > 0 or hi < 0 else "NOT distinguishable from zero"
        print(f"  vs {base}: {diff.sum():+,.0f} (95% CI {lo:+,.0f} to {hi:+,.0f}), "
              f"{diff.sum() / n_stores / weeks:+,.0f} per store per week - {verdict}")
        rows.append(("validation", "ours", f"net_saving_vs_{base}", diff.sum(), lo, hi))

    per_day, p5 = alert_quality(runs["ours"], runs["B1"], inp, VAL, role)
    print(f"\nalerts per store per day: {per_day:.1f}; precision at 5: {p5:.1%}")
    a = runs["ours"].actions
    if "action" in a:
        a = a[a["day"].between(*VAL) & a["store_id"].isin(inp.series.loc[known, "store_id"])]
        print("alerts by action:", (a["action"].value_counts() / (n_stores * (VAL[1] - VAL[0] + 1))).round(1).to_dict(),
              "per store per day")
    for name, r in table.iterrows():
        for metric in ["waste_pct", "waste_rm", "discount_given_rm", "profit_rm"]:
            rows.append(("validation", name, metric, r[metric], np.nan, np.nan))
    rows += [("validation", "ours", "alerts_per_store_day", per_day, np.nan, np.nan),
             ("validation", "ours", "precision_at_5", p5, np.nan, np.nan)]
    out = pd.DataFrame(rows, columns=["test_set", "policy", "metric", "value", "ci_low", "ci_high"])
    out.to_csv(OUT_DIR / "results_validation.csv", index=False)

    # Hand-check: five discount alerts from the last validation day, and what B1 says happened.
    a = runs["ours"].actions
    if not a.empty and "explanation" in a:
        exp = runs["B1"].expired.groupby("batch_id")["expired_qty"].sum()
        pick = a[(a["day"] == VAL[1] - 3) & (a["action"] == "discount")].head(5)
        print(f"\nhand-check (day {VAL[1] - 3}): each alert, then units of that batch wasted under B1")
        for r in pick.itertuples():
            print(f"- [{r.store_id}] {r.explanation}\n    -> under B1: {exp.get(r.batch_id, 0):.1f} units wasted")
    print(f"\nwrote {len(out)} rows to results_validation.csv ({label})")


if __name__ == "__main__":
    main()
