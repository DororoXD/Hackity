"""Give the 40 dataset SKUs a made-up identity: name, category, unit and shelf life.

The dataset only has numeric IDs, so these identities are invented for the demo.
Shelf life and unit are decided per category; names are per product.
Run: python build_catalog.py  (reads ml/out/sku_list.csv, writes product_catalog.csv)
"""
from pathlib import Path

import pandas as pd

DATA_DIR = Path(__file__).resolve().parent
SKU_LIST = DATA_DIR.parent / "ml" / "out" / "sku_list.csv"  # written by ml/load_data.py

# first_category_id -> (category, shelf_life_days, unit).
# Category 4 is split by second_category_id because greens and tomatoes spoil at very different rates.
CATEGORIES = {
    (4, 28): ("Leafy greens", 3, "kg"),
    (4, 53): ("Fruiting vegetables", 6, "kg"),
    16: ("Fruit", 7, "kg"),
    20: ("Meat & poultry", 3, "kg"),
    21: ("Seafood", 2, "kg"),
    28: ("Dairy", 10, "packs"),
    29: ("Tofu & soy", 4, "packs"),
    8: ("Bakery", 3, "loaves"),
    22: ("Eggs", 21, "trays"),
    23: ("Mushrooms", 5, "kg"),
    10: ("Fresh herbs", 4, "bunches"),
}

NAMES = {
    # Leafy greens
    140: "Spinach", 500: "Kangkung", 843: "Lettuce", 70: "Bok Choy", 21: "Choy Sum",
    215: "Kai Lan", 118: "Napa Cabbage", 554: "Watercress", 117: "Romaine Lettuce", 136: "Sawi",
    # Fruiting vegetables
    41: "Tomatoes", 774: "Cherry Tomatoes", 578: "Cucumber", 23: "Japanese Cucumber", 26: "Brinjal",
    # Fruit
    250: "Bananas", 635: "Papaya", 291: "Mangoes", 345: "Guava",
    634: "Dragon Fruit", 638: "Pineapple", 422: "Honeydew",
    # Meat & poultry
    6: "Whole Chicken", 300: "Chicken Breast", 847: "Chicken Thigh", 104: "Chicken Wings",
    122: "Minced Beef", 769: "Beef Slices", 486: "Beef Cubes", 127: "Lamb Chops",
    # Seafood
    74: "Prawns", 93: "Ikan Kembung",
    # Dairy
    834: "Fresh Milk", 411: "Greek Yogurt",
    # Tofu & soy
    4: "Firm Tofu", 596: "Fresh Soy Milk",
    # Singles
    108: "White Bread", 783: "Eggs", 644: "Button Mushrooms", 115: "Coriander",
}


def category_for(row):
    return CATEGORIES.get((row.first_category_id, row.second_category_id)) or CATEGORIES[row.first_category_id]


def main():
    skus = pd.read_csv(SKU_LIST)
    missing = set(skus.product_id) - NAMES.keys()
    if missing:
        raise SystemExit(f"No name for product_id {sorted(missing)}")

    cats = pd.DataFrame([category_for(r) for r in skus.itertuples()],
                        columns=["category", "shelf_life_days", "unit"])
    catalog = pd.concat([skus, skus.product_id.map(NAMES).rename("name"), cats], axis=1)
    catalog.to_csv(DATA_DIR / "product_catalog.csv", index=False)
    print(catalog.groupby("category").agg(products=("name", "size"), shelf_life_days=("shelf_life_days", "first")))


if __name__ == "__main__":
    main()
