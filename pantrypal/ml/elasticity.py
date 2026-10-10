"""Step 4, cut for time: placeholder discount response for every category.

+30% sales at 20% off (the runbook's fallback), linear in discount depth, so 10% off
gives x1.15 and 30% off gives x1.45. Every row is labelled source = placeholder.
Writes out/elasticity.csv. Run:  python elasticity.py
"""
import pandas as pd

from common import OUT_DIR

LIFT_PER_PCT = 0.015  # +1.5% sales per 1% off
DEPTHS = (10, 20, 30)


def main():
    categories = sorted(pd.read_csv(OUT_DIR / "sku_list.csv")["first_category_id"].unique())
    rows = [(c, d, round(1 + LIFT_PER_PCT * d, 3), "placeholder") for c in categories for d in DEPTHS]
    out = pd.DataFrame(rows, columns=["first_category_id", "discount_pct", "sales_multiplier", "source"])
    out.to_csv(OUT_DIR / "elasticity.csv", index=False)
    print(f"wrote {len(out)} rows for {len(categories)} categories (placeholder)")


if __name__ == "__main__":
    main()
