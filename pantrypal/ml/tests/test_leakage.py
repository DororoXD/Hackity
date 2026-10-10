import numpy as np
import pandas as pd

from forecast_demand import ma7_forecasts


def make_history(n_days=30):
    rng = np.random.default_rng(0)
    rows = [(s, p, d) for s in (1, 2) for p in (10, 20) for d in range(1, n_days + 1)]
    df = pd.DataFrame(rows, columns=["store_id", "product_id", "day"])
    df["dt"] = pd.Timestamp("2024-03-28") + pd.to_timedelta(df["day"] - 1, unit="D")
    df["first_category_id"] = df["product_id"] // 10
    df["role"] = "known"
    df["sale_amount"] = rng.random(len(df))
    return df


def test_ma7_uses_nothing_after_origin():
    df = make_history()
    origin = 15
    changed = df.copy()
    changed.loc[changed["day"] > origin, "sale_amount"] *= 100

    def q50_at_origin(history):
        fc = ma7_forecasts(history)
        return fc[fc["day"] == origin].sort_values(["store_id", "product_id", "horizon"])["q50"].to_numpy()

    np.testing.assert_allclose(q50_at_origin(df), q50_at_origin(changed))


def test_lgbm_features_use_nothing_after_origin():
    from train import make_features

    df = make_history()
    df["demand"] = df["sale_amount"]
    for c in ["second_category_id", "third_category_id"]:
        df[c] = df["first_category_id"]
    df["holiday_flag"] = 0
    df["discount"] = 1.0
    origin = 20
    changed = df.copy()
    changed.loc[changed["day"] > origin, "demand"] *= 100

    cols = [f"lag{k}" for k in range(7)] + ["roll7", "roll14", "past_mean"]

    def at_origin(history):
        f = make_features(history)
        return f[f["day"] == origin].sort_values(["store_id", "product_id", "horizon"])[cols].to_numpy()

    np.testing.assert_allclose(at_origin(df), at_origin(changed))
