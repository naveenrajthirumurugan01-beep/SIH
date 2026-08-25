from enum import Enum


class UserRole(str, Enum):
    CITIZEN = "citizen"
    FIELD_OFFICIAL = "field_official"
    ANALYST_ADMIN = "analyst_admin"


class RiskLevel(str, Enum):
    LOW = "low"          # green
    MEDIUM = "medium"    # amber
    HIGH = "high"        # orange
    VERY_HIGH = "very_high"  # red


class ReportStatus(str, Enum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"


class RoadStatus(str, Enum):
    CLEAR = "clear"
    PARTIALLY_OPEN = "partially_open"
    BLOCKED = "blocked"
