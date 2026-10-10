"""Step 7 of the ML runbook: LightGBM quantile forecasts (q10, q50, q90) of corrected demand.

One row per series, origin day and horizon (1-3), horizon as a feature, so three models in
total. Features use only data up to the origin day, plus the target day's calendar and
discount (discount is set to 1.0 when forecasting, so the output is no-discount demand).
store_id is never a feature. Trained on known stores' training targets, early stopping on
validation; unseen stores are only predicted.

If LightGBM beats ma7 on validation WAPE with q10-q90 coverage of 70-90%, it overwrites
out/forecasts.csv with model = lgbm. Otherwise forecasts.csv stays ma7 (the runbook fallback).
Run:  python train.py
"""
import lightgbm as lgb
import numpy as np
import pandas as pd

from common import DATA_DIR, OUT_DIR, TRAIN, VAL, load_history, unit_scale
from forecast_demand import OUT_COLS, add_quantiles, ma7_forecasts

KEYS = ["store_id", "product_id"]
HORIZONS = (1, 2, 3)
QUANTILES = {"q10": 0.1, "q50": 0.5, "q90": 0.9}
CATEGORY_COLS = ["first_category_id", "second_category_id", "third_category_id"]
FEATURES = ([f"lag{k}" for k in range(7)] + ["roll7", "roll14", "past_mean", "horizon",
            "target_dow", "target_holiday", "target_discount"] + CATEGORY_COLS)
PARAMS = dict(learning_rate=0.05, num_leaves=31, min_data_in_leaf=20, seed=42,
              deterministic=True, force_row_wise=True, verbose=-1)
MAX_TREES, EARLY_STOP = 300, 30
SCALE_GRID = np.round(np.arange(1.0, 3.01, 0.05), 2)


def make_features(df, col="demand"):
    """One row per series, origin day and horizon. Only `col` up to the origin day feeds the
    lag features; the target day contributes its calendar, holiday flag and discount."""
    df = df.sort_values(KEYS + ["day"]).reset_index(drop=True)
    g = df.groupby(KEYS)[col]
    base = df[KEYS + CATEGORY_COLS + ["role", "dt", "day"]].copy()
    for k in range(7):
        base[f"lag{k}"] = g.shift(k)
    base["roll7"] = g.transform(lambda s: s.rolling(7, min_periods=7).mean())
    base["roll14"] = g.transform(lambda s: s.rolling(14, min_periods=14).mean())
    base["past_mean"] = g.transform(lambda s: s.expanding().mean())
    rows = []
    for h in HORIZONS:
        r = base.assign(horizon=h, target=g.shift(-h),
                        target_holiday=df.groupby(KEYS)["holiday_flag"].shift(-h).fillna(0),
                        target_discount=df.groupby(KEYS)["discount"].shift(-h).fillna(1.0))
        r["target_day"] = r["day"] + h
        r["target_date"] = r["dt"] + pd.Timedelta(days=h)
        r["target_dow"] = r["target_date"].dt.dayofweek
        rows.append(r)
    return pd.concat(rows, ignore_index=True).dropna(subset=["roll14"])


def scores(actual, q10, q50, q90):
    wape = np.abs(actual - q50).sum() / actual.sum()
    coverage = ((actual >= q10) & (actual <= q90)).mean()
    pinball = np.mean([np.mean((actual - q) * (a - (actual < q))) for q, a in [(q10, .1), (q50, .5), (q90, .9)]])
    return wape, coverage, pinball


def main():
    hist = load_history()
    if "demand" not in hist:
        raise SystemExit("No corrected demand: run stockout.py first")
    hist["demand"] = hist["demand"] * unit_scale(hist)
    feats = make_features(hist)

    known = feats["role"] == "known"
    train = feats[known & (feats["target_day"] <= TRAIN[1])].dropna(subset=["target"])
    val = feats[known & feats["target_day"].between(*VAL)].dropna(subset=["target"])
    print(f"rows: train {len(train)}, validation {len(val)}")

    models, val_pred = {}, {}
    for name, alpha in QUANTILES.items():
        ds_train = lgb.Dataset(train[FEATURES], train["target"], categorical_feature=CATEGORY_COLS)
        ds_val = lgb.Dataset(val[FEATURES], val["target"], reference=ds_train)
        models[name] = lgb.train({**PARAMS, "objective": "quantile", "alpha": alpha, "metric": "quantile"},
                                 ds_train, MAX_TREES, valid_sets=[ds_val],
                                 callbacks=[lgb.early_stopping(EARLY_STOP, verbose=False)])
        val_pred[name] = models[name].predict(val[FEATURES], num_iteration=models[name].best_iteration)
        print(f"{name}: {models[name].best_iteration} trees")
    q10, q50, q90 = np.sort(np.column_stack([val_pred["q10"], val_pred["q50"], val_pred["q90"]]), axis=1).T

    # Coverage check: widen the gaps around q50 by one factor chosen on validation, only if too narrow.
    actual = val["target"].to_numpy()
    _, raw_cov, _ = scores(actual, q10, q50, q90)
    scale = 1.0
    if raw_cov < 0.70:
        covs = [scores(actual, q50 - s * (q50 - q10), q50, q50 + s * (q90 - q50))[1] for s in SCALE_GRID]
        scale = float(SCALE_GRID[int(np.argmin(np.abs(np.array(covs) - 0.80)))])
    q10, q90 = np.clip(q50 - scale * (q50 - q10), 0, None), q50 + scale * (q90 - q50)
    lgbm = scores(actual, q10, q50, q90)

    # ma7 on exactly the same validation rows.
    ma = add_quantiles(ma7_forecasts(hist, "demand"))[KEYS + ["day", "horizon", "q10", "q50", "q90"]]
    same = val[KEYS + ["day", "horizon", "target"]].merge(ma, on=KEYS + ["day", "horizon"], how="left")
    ma7 = scores(same["target"].to_numpy(), *(same[q].to_numpy() for q in ["q10", "q50", "q90"]))

    print(f"coverage before scaling {raw_cov:.1%}, scale factor {scale}")
    print(f"[validation] lgbm WAPE {lgbm[0]:.3f}, coverage {lgbm[1]:.1%}, pinball {lgbm[2]:.3f}")
    print(f"[validation] ma7  WAPE {ma7[0]:.3f}, coverage {ma7[1]:.1%}, pinball {ma7[2]:.3f}")
    gain = pd.Series(models["q50"].feature_importance("gain"), index=FEATURES).sort_values(ascending=False)
    print("top q50 features:", ", ".join(gain.index[:5]))

    passed = lgbm[0] < ma7[0] and 0.70 <= lgbm[1] <= 0.90
    (DATA_DIR.parent / "models").mkdir(exist_ok=True)
    for name, m in models.items():
        m.save_model(DATA_DIR.parent / "models" / f"lgbm_{name}.txt", num_iteration=m.best_iteration)

    # Forecast every store (unseen included) with no discount on the target day.
    fc = feats.assign(target_discount=1.0)
    pred = np.sort(np.column_stack([models[n].predict(fc[FEATURES], num_iteration=models[n].best_iteration)
                                    for n in QUANTILES]), axis=1)
    fc["q50"] = np.clip(pred[:, 1], 0, None)
    fc["q10"] = np.clip(fc["q50"] - scale * (fc["q50"] - pred[:, 0]), 0, None)
    fc["q90"] = fc["q50"] + scale * (pred[:, 2] - fc["q50"])
    fc["origin_date"] = fc["dt"].dt.strftime("%Y-%m-%d")
    fc["target_date"] = fc["target_date"].dt.strftime("%Y-%m-%d")
    fc["model"] = "lgbm"
    out = fc[OUT_COLS].sort_values(["store_id", "product_id", "origin_date", "horizon"]).round(3)
    target = OUT_DIR / ("forecasts.csv" if passed else "forecasts_lgbm_rejected.csv")
    out.to_csv(target, index=False)
    print(("PASS: lgbm beats ma7 with coverage in 70-90%; " if passed else
           "FAIL: keeping ma7 in forecasts.csv (runbook fallback); ") + f"wrote {len(out)} rows to {target.name}")


if __name__ == "__main__":
    main()
