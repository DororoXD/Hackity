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
