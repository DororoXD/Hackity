import pandas as pd

TOMATOES = 41  # shelf life 6 days, unit kg


def test_products_loaded_from_catalog(client):
    products = client.get("/products").json()
    assert len(products) == 40
    assert {"product_id": TOMATOES, "name": "Tomatoes", "category": "Fruiting vegetables",
            "shelf_life_days": 6, "unit": "kg"} in products


def test_new_batch_expires_after_shelf_life(client):
    batch = client.post("/batches", json={"product_id": TOMATOES, "quantity": 12,
                                          "received_date": "2026-10-01"}).json()
    assert batch["expiry_date"] == "2026-10-07"
    assert client.post("/batches", json={"product_id": 99999, "quantity": 1}).status_code == 404


def test_sales_import_takes_from_oldest_batch_and_reports_bad_rows(client):
    old = client.post("/batches", json={"product_id": TOMATOES, "quantity": 5, "received_date": "2026-10-01"}).json()
    new = client.post("/batches", json={"product_id": TOMATOES, "quantity": 10, "received_date": "2026-10-03"}).json()
    csv = "date,product_id,quantity\n2026-10-04,41,7\n2026-10-04,99999,1\nnot-a-date,41,1\n"
    result = client.post("/sales/import", files={"file": ("pos.csv", csv)}).json()

    assert result["rows_imported"] == 1
    assert [r["row"] for r in result["rows_rejected"]] == [3, 4]
    sold_out = [b["id"] for b in client.get("/batches", params={"status": "sold_out"}).json()]
    active = {b["id"]: b["quantity"] for b in client.get("/batches").json()}
    assert sold_out == [old["id"]]
    assert active == {new["id"]: 8}


def test_sales_import_rejects_missing_columns(client):
    response = client.post("/sales/import", files={"file": ("pos.csv", "date,qty\n2026-10-04,3\n")})
    assert response.status_code == 400


def test_alerts_for_expiring_and_expired_batches(client):
    client.post("/batches", json={"product_id": TOMATOES, "quantity": 12, "received_date": "2026-10-01",
                                  "expiry_date": "2026-10-12"})
    client.post("/batches", json={"product_id": 140, "quantity": 3, "received_date": "2026-10-01",
                                  "expiry_date": "2026-10-09"})
    # Tomatoes sell 2 kg a day over the last week: 3 sellable days left, so 6 kg of 12 will go unsold.
    csv = "date,product_id,quantity\n" + "".join(f"2026-10-0{d},41,2\n" for d in range(3, 10))
    client.post("/batches", json={"product_id": TOMATOES, "quantity": 14, "received_date": "2026-09-30",
                                  "expiry_date": "2026-10-01"})  # absorbs the imported sales
    client.post("/sales/import", files={"file": ("pos.csv", csv)})

    alerts = client.get("/alerts", params={"today": "2026-10-10"}).json()
    assert [(a["name"], a["issue_type"], a["action"], a["priority"]) for a in alerts] == [
        ("Spinach", "expired", "remove", "high"),
        ("Tomatoes", "expiring_soon", "discount", "medium"),
    ]
    tomatoes = alerts[1]
    assert (tomatoes["risk"], tomatoes["expected_waste_units"], tomatoes["rm_at_risk"]) == (1.0, 6.0, 36.0)
    assert tomatoes["discount_pct"] > 0 and tomatoes["expected_rm_saved"] > 0
    assert tomatoes["explanation"].startswith("12 kg Tomatoes expire in 2 days.")


def test_alerts_use_ml_forecasts_where_they_cover_the_date(client, monkeypatch):
    from services import alert_service

    # The ML forecast says Tomatoes sell 2 kg a day. It has nothing for Spinach, so Spinach falls back
    # to last week's sales: 1 kg a day. Sales go in before the batches so they don't use up any stock.
    days = pd.date_range("2024-06-10", periods=3)
    ml = pd.DataFrame({"store_id": alert_service.STORE_ID, "product_id": TOMATOES, "origin_date": pd.Timestamp("2024-06-09"),
                       "target_date": days, "q10": 2.0, "q50": 2.0, "q90": 2.0})
    monkeypatch.setattr(alert_service, "ml_forecasts", lambda: ml)
    csv = "date,product_id,quantity\n" + "".join(f"2024-06-0{d},140,1\n" for d in range(3, 10))
    client.post("/sales/import", files={"file": ("pos.csv", csv)})
    client.post("/batches", json={"product_id": TOMATOES, "quantity": 12, "received_date": "2024-06-06",
                                  "expiry_date": "2024-06-12"})
    client.post("/batches", json={"product_id": 140, "quantity": 5, "received_date": "2024-06-09",
                                  "expiry_date": "2024-06-11"})

    alerts = {a["name"]: a for a in client.get("/alerts", params={"today": "2024-06-10"}).json()}
    assert alerts["Tomatoes"]["expected_waste_units"] == 6.0  # 12 - 3 days x 2 kg
    assert alerts["Spinach"]["expected_waste_units"] == 3.0  # 5 - 2 days x 1 kg


def test_ml_forecasts_are_read_for_this_store():
    from services.alert_service import STORE_ID, ml_forecasts

    forecasts = ml_forecasts()
    assert len(forecasts) > 0 and set(forecasts["store_id"]) == {STORE_ID}


def test_demo_date_setting(client, monkeypatch):
    monkeypatch.setenv("PANTRYPAL_TODAY", "2024-06-10")
    batch = client.post("/batches", json={"product_id": TOMATOES, "quantity": 3}).json()
    assert (batch["received_date"], batch["expiry_date"], batch["days_left"]) == ("2024-06-10", "2024-06-16", 6)
