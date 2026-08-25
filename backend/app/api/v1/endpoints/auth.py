from fastapi import APIRouter, Depends

from app.core.security import CurrentUser, get_current_user
from app.schemas.user import UserProfileCreate, UserProfileOut

router = APIRouter()


@router.post("/register-profile", response_model=UserProfileOut)
async def register_profile(payload: UserProfileCreate):
    """Create the Firestore user profile after Firebase Auth signup.

    TODO: write to Firestore "users/{uid}" and set the custom "role" claim
    via admin.auth().set_custom_user_claims so /me and JWTs reflect it.
    """
    raise NotImplementedError


@router.get("/me", response_model=UserProfileOut)
async def get_my_profile(user: CurrentUser = Depends(get_current_user)):
    """TODO: fetch the Firestore profile doc for the authenticated user."""
    raise NotImplementedError
