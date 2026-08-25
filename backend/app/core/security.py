from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.core.firebase import get_auth_client
from app.models.user import UserRole

bearer_scheme = HTTPBearer(auto_error=True)


class CurrentUser:
    def __init__(self, uid: str, email: str | None, role: UserRole):
        self.uid = uid
        self.email = email
        self.role = role


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
) -> CurrentUser:
    """Verify the Firebase ID token from the Authorization header and load role claims.

    TODO: role is expected as a custom claim (set via Cloud Function on signup).
    """
    token = credentials.credentials
    try:
        decoded = get_auth_client().verify_id_token(token)
    except Exception as exc:  # noqa: BLE001 - surfaced as 401 regardless of cause
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired authentication token",
        ) from exc

    role = decoded.get("role", UserRole.CITIZEN.value)
    return CurrentUser(uid=decoded["uid"], email=decoded.get("email"), role=UserRole(role))


def require_roles(*allowed_roles: UserRole):
    """Dependency factory to gate an endpoint to specific roles."""

    async def _check(user: CurrentUser = Depends(get_current_user)) -> CurrentUser:
        if user.role not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have permission to perform this action",
            )
        return user

    return _check
