from datetime import date
from typing import Optional

from fastapi import APIRouter, Depends
from sqlmodel import Session

from database import get_session
from schemas import Alert
from services.alert_service import build_alerts

router = APIRouter(prefix="/alerts", tags=["alerts"])


@router.get("", response_model=list[Alert])
def list_alerts(today: Optional[date] = None, session: Session = Depends(get_session)):
    """Today's alerts, most urgent first. `today` overrides the date, for the simulator and demos."""
    return build_alerts(session, today or date.today())
