from datetime import date

import pytest
from sqlmodel import Session, select

import database
from database import Batch
from seed_demo import HISTORY_DAYS, ROLES, seed

DEMO_DATE = date(2024, 6, 20)


def test_seed_builds_a_demo_store_with_alerts(client):
    with Session(database.engine) as session:
        batches, sales = seed(session, DEMO_DATE)
    assert batches == 40 + sum(ROLES.values())  # a fresh batch per product, plus the older ones
    assert sales == 40 * HISTORY_DAYS

    alerts = client.get("/alerts", params={"today": str(DEMO_DATE)}).json()["alerts"]
    assert sum(a["action"] == "remove" for a in alerts) == ROLES["expired"]
    assert any(a["issue_type"] == "expiring_soon" for a in alerts)


def test_seed_replaces_existing_stock_and_import_history(client):
    client.post("/sales/import", files={"file": ("pos.csv", "date,product,quantity\n2024-06-19,41,2\n")})
    with Session(database.engine) as session:
        seed(session, DEMO_DATE)
        batches, _ = seed(session, DEMO_DATE)
        assert len(session.exec(select(Batch)).all()) == batches
    assert client.get("/sales/imports").json() == []


def test_seed_needs_a_date_the_forecasts_cover(client):
    with Session(database.engine) as session, pytest.raises(SystemExit, match="No ML forecast"):
        seed(session, date(2023, 1, 1))


def test_pos_export_imports_with_two_bad_rows(client, tmp_path):
    from seed_demo import write_pos_export

    path = tmp_path / "pos.csv"
    rows = write_pos_export(DEMO_DATE, path)
    result = client.post("/sales/import", params={"dry_run": True}, files={"file": ("pos.csv", path.read_text())}).json()
    assert (result["ok"], result["unmatched"], result["errors"]) == (rows - 2, 1, 1)
