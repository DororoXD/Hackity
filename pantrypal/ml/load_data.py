from pathlib import Path

import numpy as np
import pandas as pd
from datasets import load_dataset

ML_DIR = Path(__file__).resolve().parent
OUT_DIR = ML_DIR / "out"
DATA_DIR = ML_DIR / "data"

DATASET = "Dingdong-Inc/FreshRetailNet-50K"
N_STORES = 20
N_UNSEEN = 4  # test-B stores: never used for training, profiles, elasticity or tuning
N_SKUS = 40
MIN_CATEGORIES = 5
SEED = 42

CATEGORY_COLS = ["first_category_id", "second_category_id", "third_category_id"]


def pick_stores_and_skus(keys):
    """Choose the city, 20 stores and ~40 SKUs from store/product presence only (no sales)."""
    pairs = keys.drop_duplicates(["store_id", "product_id"])
    if "city_id" not in pairs.columns:
        pairs = pairs.assign(city_id=0)

    best = None
    for city, city_pairs in pairs.groupby("city_id"):
        if city_pairs["store_id"].nunique() < N_STORES:
            continue
        # Products carried by the most stores are the only ones that can be in all 20.
        top = city_pairs.groupby("product_id")["store_id"].nunique().nlargest(N_SKUS * 2).index
        stores = (city_pairs[city_pairs["product_id"].isin(top)]
                  .groupby("store_id")["product_id"].nunique()
                  .nlargest(N_STORES).index)
        coverage = (city_pairs[city_pairs["store_id"].isin(stores)]
                    .groupby("product_id")["store_id"].nunique())
        in_all = coverage[coverage == N_STORES].index
        n_cats = city_pairs.loc[city_pairs["product_id"].isin(in_all), "first_category_id"].nunique()
        score = (min(len(in_all), N_SKUS), n_cats)
        if best is None or score > best[0]:
            best = (score, city, list(stores), coverage)

    if best is None:
        raise SystemExit(f"No city has {N_STORES} stores")
    _, city, stores, coverage = best

    products = (keys.drop_duplicates("product_id").set_index("product_id")[CATEGORY_COLS]
                .loc[coverage.index]
                .assign(coverage=coverage))
    # SKUs in all 20 stores, round-robin across categories so none dominates;
    # top up with the next-best coverage only if there are too few.
    full = products[products["coverage"] == N_STORES].copy()
    full["rank_in_cat"] = full.groupby("first_category_id").cumcount()
    skus = full.sort_values(["rank_in_cat", "first_category_id"]).head(N_SKUS).drop(columns="rank_in_cat")
    if len(skus) < N_SKUS:
        rest = products.drop(skus.index).sort_values("coverage", ascending=False)
        skus = pd.concat([skus, rest.head(N_SKUS - len(skus))])
    return city, stores, skus


def main():
    OUT_DIR.mkdir(exist_ok=True)
    DATA_DIR.mkdir(exist_ok=True)

    splits = load_dataset(DATASET)  # cached under ~/.cache/huggingface, outside the repo
    print("splits:", {name: len(ds) for name, ds in splits.items()})
    train = splits["train"]

    key_cols = [c for c in ["city_id", "store_id", "product_id", *CATEGORY_COLS] if c in train.column_names]
    keys = train.select_columns(key_cols).to_pandas()
    city, stores, skus = pick_stores_and_skus(keys)

    rng = np.random.default_rng(SEED)
    unseen = set(rng.choice(stores, size=N_UNSEEN, replace=False).tolist())
    stores_df = pd.DataFrame({"store_id": stores, "city_id": city,
                              "role": ["unseen" if s in unseen else "known" for s in stores]})
    stores_df.to_csv(OUT_DIR / "stores.csv", index=False)
    skus.reset_index()[["product_id", *CATEGORY_COLS]].to_csv(OUT_DIR / "sku_list.csv", index=False)

    n_full = int((skus["coverage"] == N_STORES).sum())
    n_cats = skus["first_category_id"].nunique()
    print(f"city {city}: {len(stores)} stores ({N_UNSEEN} unseen), {len(skus)} SKUs "
          f"({n_full} in all {N_STORES} stores), {n_cats} first categories")
    if n_cats < MIN_CATEGORIES:
        print(f"WARNING: only {n_cats} first categories, runbook wants {MIN_CATEGORIES}+")
    if n_full < len(skus):
        print("WARNING: some SKUs are missing from some stores, so there are fewer than 800 series")

    store_set, sku_set = set(stores), set(skus.index)
    for name, ds in splits.items():
        sub = ds.filter(
            lambda b: [s in store_set and p in sku_set for s, p in zip(b["store_id"], b["product_id"])],
            batched=True, batch_size=100_000,
        ).to_pandas()
        sub["dt"] = pd.to_datetime(sub["dt"])
        sub = sub.sort_values(["store_id", "product_id", "dt"]).reset_index(drop=True)
        sub.to_parquet(DATA_DIR / f"subset_{name}.parquet", index=False)

        days = sub.groupby(["store_id", "product_id"])["dt"].nunique()
        bad_hours = sub["hours_sale"].map(len).ne(24).sum() + sub["hours_stock_status"].map(len).ne(24).sum()
        print(f"[{name}] rows {len(sub)}, series {len(days)}, "
              f"dates {sub['dt'].min().date()} .. {sub['dt'].max().date()} ({sub['dt'].nunique()} days), "
              f"days per series {days.min()}-{days.max()}, "
              f"missing sale_amount {sub['sale_amount'].isna().sum()}, hourly arrays not length 24: {bad_hours}")


if __name__ == "__main__":
    main()
