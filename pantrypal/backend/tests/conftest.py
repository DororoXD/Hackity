import os
import sys
from pathlib import Path

import pytest

# Use a throwaway DB, and make `import main` work from tests/.
os.environ["PANTRYPAL_DB_URL"] = "sqlite://"
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))


@pytest.fixture
def client():
    from fastapi.testclient import TestClient
    from sqlmodel import SQLModel, create_engine
    from sqlmodel.pool import StaticPool

    import database
    from main import app

    # In-memory SQLite needs one shared connection; a fresh DB per test.
    database.engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    with TestClient(app) as c:
        yield c
    SQLModel.metadata.drop_all(database.engine)
