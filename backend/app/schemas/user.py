from pydantic import BaseModel, EmailStr

from app.models.user import UserRole


class UserProfileBase(BaseModel):
    full_name: str
    phone_number: str
    district: str
    role: UserRole


class UserProfileCreate(UserProfileBase):
    uid: str
    email: EmailStr | None = None


class UserProfileOut(UserProfileBase):
    uid: str
    email: EmailStr | None = None
