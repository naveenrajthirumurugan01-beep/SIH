"""Loads the trained risk model and exposes prediction + heatmap helpers.

TODO: replace stubbed district data with live Firestore reads once the
ingestion pipeline (rainfall + terrain features) is wired up.
"""

from datetime import datetime, timezone

from app.models.user import RiskLevel
from app.schemas.risk import DistrictRisk

# Placeholder district list for early NER prototype coverage.
_STUB_DISTRICTS = [
    ("East Khasi Hills", "Meghalaya"),
    ("West Garo Hills", "Meghalaya"),
    ("Aizawl", "Mizoram"),
    ("Kohima", "Nagaland"),
    ("Gangtok", "Sikkim"),
    ("Itanagar", "Arunachal Pradesh"),
]


def score_to_level(score: float) -> RiskLevel:
    if score < 0.25:
        return RiskLevel.LOW
    if score < 0.5:
        return RiskLevel.MEDIUM
    if score < 0.75:
        return RiskLevel.HIGH
    return RiskLevel.VERY_HIGH


class RiskService:
    def __init__(self):
        self._model = None  # TODO: load via joblib.load(settings.risk_model_path)

    def get_district_heatmap(self) -> list[DistrictRisk]:
        """TODO: replace with real model inference over latest rainfall/terrain features."""
        now = datetime.now(timezone.utc)
        return [
            DistrictRisk(
                district=name,
                state=state,
                risk_level=RiskLevel.LOW,
                risk_score=0.1,
                rainfall_mm_24h=None,
                slope_avg_degrees=None,
                updated_at=now,
            )
            for name, state in _STUB_DISTRICTS
        ]

    def predict_district_risk(self, district: str) -> DistrictRisk:
        """TODO: run self._model.predict on the district's latest feature vector."""
        now = datetime.now(timezone.utc)
        return DistrictRisk(
            district=district,
            state="",
            risk_level=RiskLevel.LOW,
            risk_score=0.1,
            updated_at=now,
        )


risk_service = RiskService()
