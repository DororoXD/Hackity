from datetime import date
from typing import Optional

from fastapi import APIRouter, Depends
from sqlmodel import Session

import clock
from database import get_session
from schemas import AlertsResponse
from services.alert_service import build_alerts

router = APIRouter(prefix="/alerts", tags=["alerts"])


@router.get("", response_model=AlertsResponse)
def list_alerts(today: Optional[date] = None, session: Session = Depends(get_session)):
    """Today's alerts, most urgent first, with the totals for the summary tiles.
    `today` overrides the date, for the simulator and demos."""
    today = today or clock.today()
    alerts = build_alerts(session, today)
    return AlertsResponse(
        today=today,
        expired_or_today=sum(a.days_left <= 0 for a in alerts),
        due_soon=sum(a.days_left > 0 for a in alerts),
        total_rm_at_risk=round(sum(a.rm_at_risk for a in alerts), 2),
        total_expected_rm_saved=round(sum(a.expected_rm_saved for a in alerts), 2),
        alerts=alerts,
    )
