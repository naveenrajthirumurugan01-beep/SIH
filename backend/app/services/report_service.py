"""Report submission and review logic backed by Firestore.

TODO: wire actual Firestore reads/writes once collections are finalized.
Trust weighting: field_official reports should carry a higher trust_weight
(e.g. 2.0) than citizen reports (e.g. 1.0) when feeding the risk model.
"""

from app.models.user import ReportStatus, UserRole

TRUST_WEIGHTS = {
    UserRole.CITIZEN: 1.0,
    UserRole.FIELD_OFFICIAL: 2.0,
    UserRole.ANALYST_ADMIN: 2.0,
}


class ReportService:
    def create_report(self, reporter_uid: str, reporter_role: UserRole, payload: dict) -> dict:
        # TODO: persist to Firestore "reports" collection with trust_weight and status=PENDING
        raise NotImplementedError

    def list_reports(self, district: str | None = None, status: ReportStatus | None = None) -> list[dict]:
        # TODO: query Firestore "reports" collection with optional filters
        raise NotImplementedError

    def review_report(self, report_id: str, status: ReportStatus, reviewer_notes: str | None) -> dict:
        # TODO: update Firestore doc; analyst/admin only
        raise NotImplementedError


report_service = ReportService()
