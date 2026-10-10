from pathlib import Path

import pandas as pd

ML_DIR = Path(__file__).resolve().parent
OUT_DIR = ML_DIR / "out"
DATA_DIR = ML_DIR / "data"

# Day 1 = 2024-03-28, day 90 = 2024-06-25 (checked in step 1). Inclusive (first, last).
TRAIN = (1, 62)   # forecast model, correction profiles, elasticity
VAL = (63, 76)    # early stopping, coverage scaling, engine thresholds
TEST = (77, 90)   # final result, run once
TARGET_DAILY_UNITS = 10  # rescale so the median SKU sells about this many units a day


def load_history():
    """Subset rows for days 1-90 with a day index and each store's role (known or unseen)."""
    df = pd.read_parquet(DATA_DIR / "subset_train.parquet")
    df["dt"] = pd.to_datetime(df["dt"])
    df["day"] = (df["dt"] - df["dt"].min()).dt.days + 1
    roles = pd.read_csv(OUT_DIR / "stores.csv")[["store_id", "role"]]
    return df.merge(roles, on="store_id", how="left")


def unit_scale(df, col="sale_amount"):
    """One global factor so the median SKU sells TARGET_DAILY_UNITS a day, fitted on known stores' training days."""
    fit = df[(df["role"] == "known") & df["day"].between(*TRAIN)]
    return TARGET_DAILY_UNITS / fit.groupby("product_id")[col].mean().median()
