from fastapi import APIRouter, Depends

from app.core.security import CurrentUser, get_current_user, require_roles
from app.models.user import UserRole
from app.schemas.report import ReportCreate, ReportOut, ReportReviewAction
from app.services.report_service import report_service

router = APIRouter()


@router.post("", response_model=ReportOut)
async def submit_report(payload: ReportCreate, user: CurrentUser = Depends(get_current_user)):
    """Citizens and field officials both submit here; trust_weight differs by role."""
    return report_service.create_report(user.uid, user.role, payload.model_dump())


@router.get("", response_model=list[ReportOut])
async def list_reports(
    district: str | None = None,
    user: CurrentUser = Depends(get_current_user),
):
    return report_service.list_reports(district=district)


@router.patch("/{report_id}/review", response_model=ReportOut)
async def review_report(
    report_id: str,
    payload: ReportReviewAction,
    user: CurrentUser = Depends(require_roles(UserRole.ANALYST_ADMIN)),
):
    """Approve/reject a report. Analyst/admin only."""
    return report_service.review_report(report_id, payload.status, payload.reviewer_notes)
