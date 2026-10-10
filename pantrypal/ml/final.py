"""Step 9 of the ML runbook: the final test, run once on the frozen simulator, model and engine.

Test A: the 16 known stores on days 77-90. Test B: the 4 unseen stores on the same days.
Both come from one simulation of days 63-90 (63-76 is warm-up). Then robustness tests,
on test A, each reported as the change in ours' net saving versus the main result:
  1. 20% of sales rows removed from the history the stockout correction and the forecasts
     see (gaps interpolated); the frozen LightGBM models predict from it; true demand unchanged.
  3. Alternate simulator settings: shelf-life noise 0.30, order multiplier mean 1.1 and 1.4,
     every shelf life one day shorter and one day longer.
  4. True discount lift x0.5 and x2 while the engine keeps believing elasticity.csv.
(Test 2 is test B.)

Writes out/results.csv and out/robustness.csv. Run ONCE, after tagging model-frozen:
    python final.py        (about 15 minutes)
"""
import time

import lightgbm as lgb
import numpy as np
import pandas as pd

from backtest import ENGINE, bootstrap, engine_policy, lgbm_for_policies, per_series_profit
from common import ML_DIR, OUT_DIR, TEST, load_history, unit_scale
from forecast_demand import add_quantiles, ma7_forecasts
from policies import b1_do_nothing, b2_last_day, b3_ma_rule
from simulator import WARM_UP, Settings, assert_paired, load_inputs, ma7_for_policies, simulate, summarize
from stockout import correct
from train import FEATURES, make_features

KEYS = ["store_id", "product_id"]
LGBM_SCALE = 1.0  # coverage scale factor train.py chose on validation (it printed 1.0)
DROP_SHARE = 0.2
SEED = 11
TEST_SETS = {"test_A_later_weeks": "known", "test_B_unseen_stores": "unseen"}
T0 = time.time()


def log(msg):
    print(f"[{(time.time() - T0) / 60:4.1f} min] {msg}", flush=True)


def run(policies, inp, forecasts, settings=Settings()):
    start, end = TEST[0] - WARM_UP, TEST[1]
    out = {}
    for name, pol in policies.items():
        out[name] = simulate(pol, inp, start, end, forecasts[name], settings)
        if name != "B1":
            assert_paired(out["B1"], out[name])
    return out


def net_savings(runs, inp, role, rng, against=("B1", "B2", "B3")):
    mask = (inp.series["role"] == role).to_numpy()
    profit = {k: per_series_profit(r, inp, TEST)[mask] for k, r in runs.items()}
    res = {}
    for base in against:
        if base in profit:
            diff = profit["ours"] - profit[base]
            res[base] = (diff.sum(), *bootstrap(diff, rng))
    return res


def forecast_scores(fc, inp, role):
    """WAPE, q10-q90 coverage and pinball of forecasts whose target day is a test day."""
    idx = pd.Series(np.arange(len(inp.series)), index=pd.MultiIndex.from_frame(inp.series[KEYS]))
    f = fc.assign(target_day=fc["day"] + fc["horizon"])
    f = f[f["target_day"].between(*TEST)]
    f = f.assign(i=idx.reindex(pd.MultiIndex.from_frame(f[KEYS])).to_numpy())
    f = f[(inp.series["role"].to_numpy()[f["i"]] == role)]
    y = inp.demand[f["i"].to_numpy(), f["target_day"].to_numpy()]
    q10, q50, q90 = (f[q].to_numpy() for q in ["q10", "q50", "q90"])
    pinball = np.mean([np.mean((y - q) * (a - (y < q))) for q, a in [(q10, .1), (q50, .5), (q90, .9)]])
    return {"wape": np.abs(y - q50).sum() / y.sum(), "coverage": ((y >= q10) & (y <= q90)).mean(),
            "pinball": pinball}


def lgbm_predict(models, demand_hist):
    """Frozen LightGBM forecasts (no discount on the target day) in the simulator's format."""
    fc = make_features(demand_hist).assign(target_discount=1.0)
    pred = np.sort(np.column_stack([models[n].predict(fc[FEATURES]) for n in ["q10", "q50", "q90"]]), axis=1)
    fc["q50"] = np.clip(pred[:, 1], 0, None)
    fc["q10"] = np.clip(fc["q50"] - LGBM_SCALE * (fc["q50"] - pred[:, 0]), 0, None)
    fc["q90"] = fc["q50"] + LGBM_SCALE * (pred[:, 2] - fc["q50"])
    fc["origin_date"] = fc["dt"]
    return fc[KEYS + ["day", "horizon", "origin_date", "target_date", "q10", "q50", "q90"]]


def exact_scale():
    """unit_scale unrounded, as train.py used it (sku_params.csv rounds it, which moves a few
    rows across LightGBM splits)."""
    return unit_scale(load_history(corrected=False))


def degraded_history(scale, rng):
    """Corrected demand after dropping DROP_SHARE of sales rows; gaps interpolated per series."""
    hist = load_history(corrected=False)
    kept = hist[rng.random(len(hist)) >= DROP_SHARE].reset_index(drop=True)
    demand, _, _ = correct(kept)
    kept = kept.assign(demand=demand)[KEYS + ["day", "demand"]]
    calendar = hist[KEYS + ["day", "dt", "first_category_id", "second_category_id", "third_category_id",
                            "role", "holiday_flag", "discount"]]
    full = calendar.merge(kept, on=KEYS + ["day"], how="left").sort_values(KEYS + ["day"])
    full["demand"] = full.groupby(KEYS)["demand"].transform(lambda s: s.interpolate(limit_direction="both"))
    full["demand"] = full["demand"] * scale
    return full


def main():
    inp = load_inputs()
    sku_params = pd.read_csv(OUT_DIR / "sku_params.csv")
    ours_fc = lgbm_for_policies(inp)
    model = ours_fc["model"].iloc[0]
    ma7 = ma7_for_policies(inp)
    ours = engine_policy(sku_params)
    label = f"{ENGINE}, {model} forecasts"
    log(f"final test on days {TEST[0]}-{TEST[1]} (warm-up from {TEST[0] - WARM_UP}); ours = {label}")

    policies = {"B1": b1_do_nothing, "B2": b2_last_day, "B3": b3_ma_rule, "ours": ours}
    forecasts = {"B1": ma7, "B2": ma7, "B3": ma7, "ours": ours_fc}
    main_runs = run(policies, inp, forecasts)
    log("main run done")

    rng = np.random.default_rng(SEED)
    rows, main_saving = [], {}
    stores_per_role = inp.series.groupby("role")["store_id"].nunique()
    weeks = (TEST[1] - TEST[0] + 1) / 7
    lgbm_rows = ours_fc[ours_fc["model"] == "lgbm"] if model == "lgbm" else None
    for test_set, role in TEST_SETS.items():
        n_stores = stores_per_role[role]
        print(f"\n=== {test_set} ({n_stores} stores, simulated RM) ===")
        table = pd.DataFrame({k: summarize(r, inp, TEST, role) for k, r in main_runs.items()}).T
        print(table[["waste_pct", "waste_rm", "discount_given_rm", "profit_rm"]].round(3).to_string())
        for name, r in table.iterrows():
            for metric in ["waste_pct", "waste_rm", "discount_given_rm", "revenue_rm", "profit_rm"]:
                rows.append((test_set, name, metric, r[metric], np.nan, np.nan))

        for base, (total, lo, hi) in net_savings(main_runs, inp, role, rng).items():
            verdict = "distinguishable" if lo > 0 or hi < 0 else "NOT distinguishable from zero"
            per = n_stores * weeks
            print(f"ours vs {base}: {total:+,.0f} (95% CI {lo:+,.0f} to {hi:+,.0f}); "
                  f"{total / per:+,.0f} per store per week (CI {lo / per:+,.0f} to {hi / per:+,.0f}) - {verdict}")
            rows.append((test_set, "ours", f"net_saving_vs_{base}", total, lo, hi))
            rows.append((test_set, "ours", f"net_saving_vs_{base}_per_store_week", total / per, lo / per, hi / per))
            if role == "known":
                main_saving[base] = total

        a = main_runs["ours"].actions
        roles = inp.series.drop_duplicates("store_id").set_index("store_id")["role"]
        a = a[a["day"].between(*TEST) & (a["store_id"].map(roles) == role)] if not a.empty else a
        store_days = n_stores * (TEST[1] - TEST[0] + 1)
        all_alerts = len(a) / store_days
        actionable = (a["action"] != "monitor").sum() / store_days if "action" in a else all_alerts
        wasted_b1 = set(main_runs["B1"].expired.query("expired_qty > 1e-9")["batch_id"])
        pred = a[a["issue_type"] == "expiring_soon"] if "issue_type" in a else a.iloc[:0]
        top5 = pred.sort_values("rm_at_risk", ascending=False).groupby(["store_id", "day"]).head(5)
        p5 = top5["batch_id"].isin(wasted_b1).mean() if len(top5) else np.nan
        print(f"alerts per store per day: {all_alerts:.1f} ({actionable:.1f} actionable, monitor excluded); "
              f"precision at 5: {p5:.1%}")
        rows += [(test_set, "ours", "alerts_per_store_day", all_alerts, np.nan, np.nan),
                 (test_set, "ours", "actionable_alerts_per_store_day", actionable, np.nan, np.nan),
                 (test_set, "ours", "precision_at_5", p5, np.nan, np.nan)]

        for name, fc in [("ma7", ma7), (model, ours_fc)]:
            s = forecast_scores(fc, inp, role)
            print(f"forecast {name}: WAPE {s['wape']:.3f}, coverage {s['coverage']:.1%}, pinball {s['pinball']:.3f}")
            rows += [(test_set, name, f"forecast_{m}", v, np.nan, np.nan) for m, v in s.items()]

    results = pd.DataFrame(rows, columns=["test_set", "policy", "metric", "value", "ci_low", "ci_high"])
    results.to_csv(OUT_DIR / "results.csv", index=False)
    log(f"wrote results.csv ({len(results)} rows); starting robustness tests on test A")

    robust = []

    def record(test, runs):
        for base, (total, _, _) in net_savings(runs, inp, "known", rng, ("B1", "B3")).items():
            robust.append((test, f"ours_vs_{base}", total, total - main_saving[base]))
        log(f"{test}: ours vs B1 {robust[-2][2]:+,.0f} ({robust[-2][3]:+,.0f} vs main), "
            f"vs B3 {robust[-1][2]:+,.0f} ({robust[-1][3]:+,.0f} vs main)")

    trio = {"B1": b1_do_nothing, "B3": b3_ma_rule, "ours": ours}

    # 1. 20% of sales rows missing from what the correction and the forecasters see.
    if model == "lgbm":
        models = {n: lgb.Booster(model_file=str(ML_DIR / "models" / f"lgbm_{n}.txt")) for n in ["q10", "q50", "q90"]}
        full = load_history()
        full["demand"] = full["demand"] * exact_scale()
        same = lgbm_predict(models, full).merge(ours_fc, on=KEYS + ["day", "horizon"], suffixes=("", "_csv"))
        log(f"reloaded models reproduce forecasts.csv within {np.abs(same['q50'] - same['q50_csv']).max():.3f} units")
        deg = degraded_history(exact_scale(), np.random.default_rng(SEED))
        deg_ours = lgbm_predict(models, deg)
    else:
        deg = degraded_history(exact_scale(), np.random.default_rng(SEED))
        deg_ours = add_quantiles(ma7_forecasts(deg, "demand")).assign(origin_date=lambda f: f["dt"])
    deg_ma7 = add_quantiles(ma7_forecasts(deg, "demand"))
    record("1_missing_20pct_sales_rows", run(trio, inp, {"B1": deg_ma7, "B3": deg_ma7, "ours": deg_ours}))

    # 3. Alternate simulator settings. 4. Discount response mismatch.
    fc3 = {"B1": ma7, "B3": ma7, "ours": ours_fc}
    for test, settings in [("3_shelf_life_noise_0.30", Settings(life_sigma=0.30)),
                           ("3_order_multiplier_1.1", Settings(k_mean=1.1)),
                           ("3_order_multiplier_1.4", Settings(k_mean=1.4)),
                           ("3_shelf_life_minus_1_day", Settings(life_shift=-1)),
                           ("3_shelf_life_plus_1_day", Settings(life_shift=1)),
                           ("4_true_lift_x0.5", Settings(lift_scale=0.5)),
                           ("4_true_lift_x2", Settings(lift_scale=2.0))]:
        record(test, run(trio, inp, fc3, settings))

    pd.DataFrame(robust, columns=["test", "policy", "net_saving", "change_vs_main"]).to_csv(
        OUT_DIR / "robustness.csv", index=False)
    log(f"wrote robustness.csv ({len(robust)} rows); ours = {label}. Do not rerun after reading these numbers.")


if __name__ == "__main__":
    main()
