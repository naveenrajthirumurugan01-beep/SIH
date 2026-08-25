from datetime import datetime

from pydantic import BaseModel

from app.models.user import RiskLevel


class DistrictRisk(BaseModel):
    district: str
    state: str
    risk_level: RiskLevel
    risk_score: float  # 0-1 continuous score backing the bucketed level
    rainfall_mm_24h: float | None = None
    slope_avg_degrees: float | None = None
    updated_at: datetime


class RiskMapResponse(BaseModel):
    districts: list[DistrictRisk]
    generated_at: datetime


class AlertTrigger(BaseModel):
    district: str
    risk_level: RiskLevel
    message: str
    send_sms: bool = True
    send_push: bool = True
