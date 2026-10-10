"""Step 3 of the ML runbook: stockout-corrected daily demand.

1. Each product's share of daily sales by hour, from known stores' training days with no
   stockout hours (stock_hour6_22_cnt = 0).
2. On a stockout day, demand = observed sales / profile share of the hours that were in
   stock, capped at 3x observed sales.
3. If the in-stock hours hold under 20% of the profile, use the series' median sales on its
   non-stockout training days instead.

Writes data/demand.parquet in dataset units; load_history() adds it as the `demand` column.
Run:  python stockout.py
"""
import numpy as np
import pandas as pd

from common import DATA_DIR, TRAIN, load_history

STOCK_HOURS = slice(6, 22)  # 06:00-22:00, the window stock_hour6_22_cnt counts
CAP = 3.0
MIN_IN_STOCK_SHARE = 0.2
KEYS = ["store_id", "product_id"]


def hourly_profiles(df, sales):
    """Per-row 24-hour sales profile: the row's product, else its category, else all products."""
    clean = ((df["role"] == "known") & df["day"].between(*TRAIN) & (df["stock_hour6_22_cnt"] == 0)).to_numpy()

    def shares(key):
        totals = pd.DataFrame(sales[clean]).groupby(df.loc[clean, key].to_numpy()).sum()
        return totals.div(totals.sum(axis=1), axis=0)  # all-zero products become NaN and fall back

    prof = shares("product_id").reindex(df["product_id"]).to_numpy(dtype=float, copy=True)
    missing = np.isnan(prof).any(axis=1)
    prof[missing] = shares("first_category_id").reindex(df.loc[missing, "first_category_id"]).to_numpy()
    missing = np.isnan(prof).any(axis=1)
    prof[missing] = sales[clean].sum(axis=0) / sales[clean].sum()
    return prof


def correct(df):
    sales = np.stack(df["hours_sale"].to_numpy()).astype(float)
    status = np.stack(df["hours_stock_status"].to_numpy())
    observed = df["sale_amount"].to_numpy(dtype=float)
    stockout = df["stock_hour6_22_cnt"].to_numpy() > 0

    out_hours = np.zeros(status.shape, dtype=bool)
    out_hours[:, STOCK_HOURS] = status[:, STOCK_HOURS] == 1
    in_stock_share = 1 - (hourly_profiles(df, sales) * out_hours).sum(axis=1)

    scaled = observed / np.maximum(in_stock_share, 1e-9)
    demand = np.where(stockout, np.minimum(CAP * observed, scaled), observed)
    correction = np.where(~stockout, "none", np.where(scaled > CAP * observed, "capped", "scaled"))

    train_clean = ~stockout & df["day"].between(*TRAIN).to_numpy()
    median = df[train_clean].groupby(KEYS)["sale_amount"].median()
    series_median = median.reindex(pd.MultiIndex.from_frame(df[KEYS])).to_numpy()
    use_median = stockout & (in_stock_share < MIN_IN_STOCK_SHARE) & ~np.isnan(series_median)
    demand = np.where(use_median, np.maximum(observed, series_median), demand)
    correction = np.where(use_median, "median", correction)

    assert (demand >= observed - 1e-9).all(), "corrected demand fell below observed sales"
    agree = (out_hours.sum(axis=1) == df["stock_hour6_22_cnt"].to_numpy()).mean()
    return demand, correction, agree


def main():
    df = load_history(corrected=False)
    demand, correction, agree = correct(df)
    observed = df["sale_amount"].to_numpy(dtype=float)

    out = df[KEYS + ["day"]].assign(demand=demand, correction=correction)
    out.to_parquet(DATA_DIR / "demand.parquet", index=False)

    stockout = correction != "none"
    sold = stockout & (observed > 0)
    print(f"stockout days: {stockout.mean():.1%} of {len(df)} store-days")
    print("corrections:", pd.Series(correction[stockout]).value_counts().to_dict())
    print(f"uplift on stockout days: x{demand[stockout].sum() / observed[stockout].sum():.2f} in total, "
          f"median day x{np.median(demand[sold] / observed[sold]):.2f}")
    print(f"total demand vs observed: +{demand.sum() / observed.sum() - 1:.1%}")
    print(f"hourly flags match stock_hour6_22_cnt on {agree:.1%} of rows")


if __name__ == "__main__":
    main()
