from fastapi import APIRouter, Depends

from app.core.security import CurrentUser, require_roles
from app.models.user import UserRole
from app.schemas.risk import AlertTrigger

router = APIRouter()


@router.post("/trigger")
async def trigger_alert(
    payload: AlertTrigger,
    user: CurrentUser = Depends(require_roles(UserRole.ANALYST_ADMIN)),
):
    """Manually trigger or override an alert for a district. Analyst/admin only.

    TODO: fan out to (1) FCM push via Cloud Messaging topic per district,
    (2) SMS via app.services.sms_service for subscribed numbers in that
    district. Automatic threshold-based triggers live in the Cloud Function
    (functions/src) that watches the risk collection.
    """
    raise NotImplementedError
