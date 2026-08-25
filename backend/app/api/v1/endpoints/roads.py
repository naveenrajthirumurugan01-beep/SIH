from fastapi import APIRouter, Depends

from app.core.security import CurrentUser, require_roles
from app.models.user import RoadStatus, UserRole

router = APIRouter()


@router.patch("/{road_id}/status")
async def update_road_status(
    road_id: str,
    status: RoadStatus,
    user: CurrentUser = Depends(require_roles(UserRole.FIELD_OFFICIAL, UserRole.ANALYST_ADMIN)),
):
    """Field officials and analysts can update road connectivity status.

    TODO: persist to Firestore "roads/{road_id}" and surface on the risk map
    and emergency-response prioritization view.
    """
    raise NotImplementedError
