"""Writes out/sku_params.csv: price, cost, shelf life and unit scale per product.

Shelf life comes from UI/UX 2's data/product_catalog.csv. Prices are placeholders by
category (RM per unit) and cost is 65% of price. Both are guesses, so every RM figure
built on them is "simulated".
Run:  python shelf_life.py
"""
import pandas as pd

from common import ML_DIR, OUT_DIR, load_history, unit_scale

CATALOG = ML_DIR.parent / "data" / "product_catalog.csv"
COST_SHARE = 0.65
DEFAULT_PRICE = 8.0
PRICE_BY_CATEGORY = {  # RM per unit, placeholders
    "Leafy greens": 6.0, "Fruiting vegetables": 6.0, "Fruit": 8.0, "Meat & poultry": 20.0,
    "Seafood": 30.0, "Dairy": 8.0, "Tofu & soy": 3.5, "Bakery": 4.5, "Eggs": 13.0,
    "Mushrooms": 12.0, "Fresh herbs": 2.0,
}


def main():
    catalog = pd.read_csv(CATALOG)
    skus = pd.read_csv(OUT_DIR / "sku_list.csv")
    if set(catalog["product_id"]) != set(skus["product_id"]):
        raise SystemExit("product_catalog.csv and sku_list.csv list different products")
    unknown = sorted(set(catalog["category"]) - PRICE_BY_CATEGORY.keys())
    if unknown:
        print(f"WARNING: no placeholder price for {unknown}, using RM {DEFAULT_PRICE}")

    params = pd.DataFrame({
        "product_id": catalog["product_id"],
        "price": catalog["category"].map(PRICE_BY_CATEGORY).fillna(DEFAULT_PRICE),
    })
    params["cost"] = (params["price"] * COST_SHARE).round(2)
    params["shelf_life_days"] = catalog["shelf_life_days"]
    params["unit_scale"] = round(unit_scale(load_history(corrected=False)), 4)
    params.to_csv(OUT_DIR / "sku_params.csv", index=False)
    print(f"wrote {len(params)} products, unit_scale {params['unit_scale'].iloc[0]}, "
          f"shelf life {params['shelf_life_days'].min()}-{params['shelf_life_days'].max()} days")


if __name__ == "__main__":
    main()
