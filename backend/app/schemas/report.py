from datetime import datetime

from pydantic import BaseModel, Field

from app.models.user import ReportStatus, RoadStatus


class GeoPoint(BaseModel):
    lat: float
    lng: float


class ReportCreate(BaseModel):
    description: str
    geo_point: GeoPoint
    district: str
    media_urls: list[str] = Field(default_factory=list)
    road_status: RoadStatus | None = None  # field officials only


class ReportOut(BaseModel):
    id: str
    reporter_uid: str
    reporter_role: str
    description: str
    geo_point: GeoPoint
    district: str
    media_urls: list[str]
    road_status: RoadStatus | None
    status: ReportStatus
    trust_weight: float
    created_at: datetime


class ReportReviewAction(BaseModel):
    status: ReportStatus
    reviewer_notes: str | None = None
