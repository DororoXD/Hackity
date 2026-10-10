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
    csv = "date,product,quantity\n2026-10-04,41,7\n2026-10-04,99999,1\nnot-a-date,41,1\n"
    result = client.post("/sales/import", files={"file": ("pos.csv", csv)}).json()

    assert (result["ok"], result["unmatched"], result["errors"], result["imported"]) == (1, 1, 1, 1)
    assert [r["status"] for r in result["rows"]] == ["ok", "unmatched", "bad_date"]
    sold_out = [b["id"] for b in client.get("/batches", params={"status": "sold_out"}).json()]
    active = {b["id"]: b["quantity"] for b in client.get("/batches").json()}
    assert sold_out == [old["id"]]
    assert active == {new["id"]: 8}


def test_sales_only_come_from_batches_on_the_shelf_that_day(client):
    expired = client.post("/batches", json={"product_id": TOMATOES, "quantity": 5, "received_date": "2026-09-25"}).json()
    on_shelf = client.post("/batches", json={"product_id": TOMATOES, "quantity": 5, "received_date": "2026-10-01"}).json()
    later = client.post("/batches", json={"product_id": TOMATOES, "quantity": 5, "received_date": "2026-10-06"}).json()
    client.post("/sales/import", files={"file": ("pos.csv", "date,product,quantity\n2026-10-04,41,3\n")})

    remaining = {b["id"]: b["quantity"] for b in client.get("/batches").json()}
    assert remaining == {expired["id"]: 5, on_shelf["id"]: 2, later["id"]: 5}


def test_sales_import_rejects_missing_columns(client):
    response = client.post("/sales/import", files={"file": ("pos.csv", "date,qty\n2026-10-04,3\n")})
    assert response.status_code == 400
    assert response.json()["detail"] == "Column not found: product, quantity. The file has: date, qty"


def test_sales_import_matches_names_and_reads_pos_formats(client):
    client.post("/batches", json={"product_id": TOMATOES, "quantity": 10, "received_date": "2026-10-01"})
    csv = ("Sold On,Item,Qty\n"
           "04/10/2026,tomatoes,3\n"      # name in any case, DD/MM/YYYY
           "2026-10-04, Fresh Milk ,2\n"  # spaces around the name
           "04/10/2026,Strawberries 250g,6\n"
           "32/10/2026,Greek Yogurt,9\n"
           "04/10/2026,Greek Yogurt,-1\n")
    columns = {"date_column": "Sold On", "product_column": "Item", "quantity_column": "Qty"}

    preview = client.post("/sales/import", params={**columns, "dry_run": True}, files={"file": ("pos.csv", csv)}).json()
    assert [(r["name"], r["sale_date"], r["status"]) for r in preview["rows"]] == [
        ("Tomatoes", "2026-10-04", "ok"),
        ("Fresh Milk", "2026-10-04", "ok"),
        (None, "2026-10-04", "unmatched"),
        ("Greek Yogurt", None, "bad_date"),
        ("Greek Yogurt", "2026-10-04", "bad_quantity"),
    ]
    assert (preview["ok"], preview["unmatched"], preview["errors"], preview["imported"]) == (2, 1, 2, 0)
    assert client.get("/batches").json()[0]["quantity"] == 10  # a dry run changes nothing

    result = client.post("/sales/import", params=columns, files={"file": ("pos.csv", csv)}).json()
    assert result["imported"] == 2
    assert client.get("/batches").json()[0]["quantity"] == 7


def test_alerts_for_expiring_and_expired_batches(client):
    client.post("/batches", json={"product_id": TOMATOES, "quantity": 12, "received_date": "2026-10-01",
                                  "expiry_date": "2026-10-12"})
    client.post("/batches", json={"product_id": 140, "quantity": 3, "received_date": "2026-10-01",
                                  "expiry_date": "2026-10-09"})
    # Tomatoes sell 2 kg a day over the last week: 3 sellable days left, so 6 kg of 12 will go unsold.
    csv = "date,product,quantity\n" + "".join(f"2026-10-0{d},41,2\n" for d in range(3, 10))
    client.post("/batches", json={"product_id": TOMATOES, "quantity": 14, "received_date": "2026-10-02",
                                  "expiry_date": "2026-10-09"})  # on the shelf all week; absorbs the imported sales
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
    csv = "date,product,quantity\n" + "".join(f"2024-06-0{d},140,1\n" for d in range(3, 10))
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
