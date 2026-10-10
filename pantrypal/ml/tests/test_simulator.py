"""The simulator's guarantees: identical batches for every policy, identical numbers on a
rerun, no overselling, markdowns that only touch their batch, and the runbook's B1/B2 check."""
import numpy as np
import pandas as pd

from policies import b1_do_nothing, b2_last_day
from simulator import Inputs, Settings, assert_paired, simulate, summarize


def make_inputs(n_series=4, demand_per_day=10.0):
    series = pd.DataFrame({
        "store_id": np.repeat([1, 2], n_series // 2), "product_id": np.tile([10, 20], n_series // 2),
        "first_category_id": 4, "role": "known", "price": 6.0, "cost": 3.9, "shelf_life_days": 3,
    })
    demand = np.zeros((n_series, 91))
    demand[:, 1:] = np.random.default_rng(0).gamma(4, demand_per_day / 4, (n_series, 90))
    elasticity = pd.DataFrame({"first_category_id": 4, "discount_pct": [10, 20, 30],
                               "sales_multiplier": [1.15, 1.30, 1.45], "source": "placeholder"})
    return Inputs(series, demand, elasticity, pd.Timestamp("2024-03-28"))


def test_rerun_identical_and_batches_paired():
    inp = make_inputs()
    a = simulate(b1_do_nothing, inp, 49, 76)
    b = simulate(b1_do_nothing, inp, 49, 76)
    pd.testing.assert_frame_equal(a.daily, b.daily)
    assert_paired(a, simulate(b2_last_day, inp, 49, 76))


def test_stock_is_conserved_and_never_oversold():
    inp = make_inputs()
    r = simulate(b2_last_day, inp, 49, 76)
    d = r.daily
    assert (d["lost"] >= 0).all() and (d["sold"] <= d["demand"] * 1.45 + 1e-9).all()
    on_hand_end = d["received"].sum() - d["sold"].sum() - d["wasted"].sum()
    assert on_hand_end >= -1e-6


def test_b1_wastes_and_b2_wastes_less():
    inp = make_inputs()
    b1 = summarize(simulate(b1_do_nothing, inp, 49, 76), inp, (63, 76))
    b2 = summarize(simulate(b2_last_day, inp, 49, 76), inp, (63, 76))
    assert b1["waste_units"] > 0
    assert b2["waste_units"] < b1["waste_units"]


def test_batches_expire_at_their_shelf_life_without_noise():
    inp = make_inputs(n_series=2)
    inp.demand[:, 1:] = 1.0  # tiny demand, so stock is left to expire
    r = simulate(b1_do_nothing, inp, 49, 60, settings=Settings(life_sigma=0.0))
    expired = r.expired.merge(r.received, on="batch_id")
    assert len(expired) > 0
    assert (expired["expired_day"] - expired["received_day"] == 3).all()


def test_markdown_only_cheapens_the_discounted_batch():
    inp = make_inputs(n_series=2)

    def mark_down_everything(batches, today, forecasts, sku_params, elasticity):
        return batches[["store_id", "product_id", "batch_id"]].assign(discount_pct=20)

    def mark_down_nothing_real(batches, today, forecasts, sku_params, elasticity):
        return batches[["store_id", "product_id", "batch_id"]].iloc[:0].assign(discount_pct=20)

    all_off = simulate(mark_down_everything, inp, 49, 60).daily
    none_off = simulate(mark_down_nothing_real, inp, 49, 60).daily
    assert np.isclose(all_off["discount_given"].sum(), (all_off["revenue"] / 0.8 * 0.2).sum())
    assert none_off["discount_given"].sum() == 0
