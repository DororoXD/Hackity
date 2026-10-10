from datetime import date
from typing import Optional

from fastapi import APIRouter, Depends
from sqlmodel import Session

import clock
from database import get_session
from schemas import Action, AlertsResponse
from services.alert_service import build_alerts

router = APIRouter(prefix="/alerts", tags=["alerts"])


@router.get("", response_model=AlertsResponse)
def list_alerts(today: Optional[date] = None, include_monitor: bool = False, session: Session = Depends(get_session)):
    """Today's alerts, most urgent first, with the totals for the summary tiles.

    Only alerts with something to do (discount, donate, remove) are listed and totalled; "monitor" ones
    are just counted, unless include_monitor=true. `today` overrides the date, for the simulator and demos.
    """
    today = today or clock.today()
    everything = build_alerts(session, today)
    alerts = [a for a in everything if include_monitor or a.action != Action.monitor]
    return AlertsResponse(
        today=today,
        expired_or_today=sum(a.days_left <= 0 for a in alerts),
        due_soon=sum(a.days_left > 0 for a in alerts),
        total_rm_at_risk=round(sum(a.rm_at_risk for a in alerts), 2),
        total_expected_rm_saved=round(sum(a.expected_rm_saved for a in alerts), 2),
        monitoring=sum(a.action == Action.monitor for a in everything),
        alerts=alerts,
    )
