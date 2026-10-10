"""Write a real response from every endpoint to pantrypal/assets/mock/*.json, for the Flutter app's mock mode.

Uses a throwaway database seeded with the demo store (seed_demo.py), so your own pantrypal.db is untouched.
Run from this folder after changing an endpoint:  python export_mocks.py
"""
import json
import os
import tempfile
from pathlib import Path

DEMO_DATE = "2024-06-20"
MOCK_DIR = Path(__file__).resolve().parent.parent / "assets" / "mock"
POS_EXPORT = Path(__file__).resolve().parent.parent / "data" / "sample_pos_export.csv"


def main():
    db = Path(tempfile.mkdtemp()) / "mocks.db"
    os.environ["PANTRYPAL_DB_URL"] = f"sqlite:///{db}"
    os.environ["PANTRYPAL_TODAY"] = DEMO_DATE

    # Imported here so they pick up the throwaway database and demo date set above.
    from datetime import date

    from fastapi.testclient import TestClient
    from sqlmodel import Session

    import database
    from main import app
    from seed_demo import seed

    def save(name, response):
        response.raise_for_status()
        (MOCK_DIR / f"{name}.json").write_text(json.dumps(response.json(), indent=2) + "\n")
        print(f"wrote {name}.json")

    pos_file = {"file": (POS_EXPORT.name, POS_EXPORT.read_text())}
    with TestClient(app) as client:
        with Session(database.engine) as session:
            seed(session, date.fromisoformat(DEMO_DATE))
        save("today", client.get("/today"))
        save("products", client.get("/products"))
        save("stock", client.get("/stock"))
        save("batches", client.get("/batches"))
        save("alerts", client.get("/alerts"))
        save("sales_import_preview", client.post("/sales/import", params={"dry_run": True}, files=pos_file))
        save("batch_created", client.post("/batches", json={"product_id": 41, "quantity": 12}))
        save("sales_import_done", client.post("/sales/import", files=pos_file))
        save("sales_imports", client.get("/sales/imports"))
    database.engine.dispose()
    db.unlink()


if __name__ == "__main__":
    main()
