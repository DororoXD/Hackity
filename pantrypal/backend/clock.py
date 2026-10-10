"""The app's idea of today. Set PANTRYPAL_TODAY=YYYY-MM-DD to run on a fixed date instead of the real one,
e.g. a date inside ml/out/forecasts.csv so the demo uses the ML forecasts."""
import os
from datetime import date


def today() -> date:
    fixed = os.environ.get("PANTRYPAL_TODAY")
    return date.fromisoformat(fixed) if fixed else date.today()
