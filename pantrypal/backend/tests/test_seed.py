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

    alerts = client.get("/alerts", params={"today": str(DEMO_DATE)}).json()
    assert sum(a["action"] == "remove" for a in alerts) == ROLES["expired"]
    assert any(a["issue_type"] == "expiring_soon" for a in alerts)


def test_seed_replaces_existing_stock(client):
    with Session(database.engine) as session:
        seed(session, DEMO_DATE)
        batches, _ = seed(session, DEMO_DATE)
        assert len(session.exec(select(Batch)).all()) == batches


def test_seed_needs_a_date_the_forecasts_cover(client):
    with Session(database.engine) as session, pytest.raises(SystemExit, match="No ML forecast"):
        seed(session, date(2023, 1, 1))
