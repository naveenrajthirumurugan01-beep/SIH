from datetime import datetime, timezone

from fastapi import APIRouter, Depends

from app.core.security import CurrentUser, get_current_user
from app.schemas.risk import DistrictRisk, RiskMapResponse
from app.services.risk_service import risk_service

router = APIRouter()


@router.get("/heatmap", response_model=RiskMapResponse)
async def get_risk_heatmap(user: CurrentUser = Depends(get_current_user)):
    """Color-coded district risk levels for the map screen.

    Detail level (rainfall/slope figures vs. just the color band) is
    filtered by role on the Flutter side per the UI spec; this endpoint
    returns the full payload and lets the client decide what to render.
    """
    districts = risk_service.get_district_heatmap()
    return RiskMapResponse(districts=districts, generated_at=datetime.now(timezone.utc))


@router.get("/district/{district_name}", response_model=DistrictRisk)
async def get_district_risk(district_name: str, user: CurrentUser = Depends(get_current_user)):
    return risk_service.predict_district_risk(district_name)
