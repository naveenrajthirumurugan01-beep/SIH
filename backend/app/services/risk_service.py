"""Loads the trained risk model and exposes ML prediction + heatmap helpers.
"""

import os
from datetime import datetime, timezone
import joblib
import pandas as pd

from app.models.user import RiskLevel
from app.schemas.risk import DistrictRisk

_BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
MODEL_PATH = os.path.join(_BASE_DIR, "ml", "models", "risk_model.joblib")

# Rich NER District Feature Profiles (Rainfall 24h/72h/7d, Slope, Elevation, Soil Saturation, Historical Incidents)
_NER_DISTRICT_PROFILES = {
    "East Khasi Hills": {
        "state": "Meghalaya",
        "rainfall_24h_mm": 210.0,
        "rainfall_72h_mm": 420.0,
        "rainfall_7d_mm": 850.0,
        "slope_avg_degrees": 45.0,
        "elevation_m": 1500.0,
        "soil_saturation_index": 0.88,
        "historical_incident_count": 8,
        "lat": 25.5788,
        "lng": 91.8933,
    },
    "Aizawl": {
        "state": "Mizoram",
        "rainfall_24h_mm": 185.0,
        "rainfall_72h_mm": 370.0,
        "rainfall_7d_mm": 710.0,
        "slope_avg_degrees": 42.0,
        "elevation_m": 1132.0,
        "soil_saturation_index": 0.82,
        "historical_incident_count": 6,
        "lat": 23.7271,
        "lng": 92.7176,
    },
    "Gangtok": {
        "state": "Sikkim",
        "rainfall_24h_mm": 160.0,
        "rainfall_72h_mm": 310.0,
        "rainfall_7d_mm": 620.0,
        "slope_avg_degrees": 48.0,
        "elevation_m": 1650.0,
        "soil_saturation_index": 0.79,
        "historical_incident_count": 7,
        "lat": 27.3389,
        "lng": 88.6065,
    },
    "Kohima": {
        "state": "Nagaland",
        "rainfall_24h_mm": 125.0,
        "rainfall_72h_mm": 240.0,
        "rainfall_7d_mm": 480.0,
        "slope_avg_degrees": 38.0,
        "elevation_m": 1444.0,
        "soil_saturation_index": 0.68,
        "historical_incident_count": 4,
        "lat": 25.6751,
        "lng": 94.1086,
    },
    "Itanagar": {
        "state": "Arunachal Pradesh",
        "rainfall_24h_mm": 140.0,
        "rainfall_72h_mm": 260.0,
        "rainfall_7d_mm": 510.0,
        "slope_avg_degrees": 40.0,
        "elevation_m": 750.0,
        "soil_saturation_index": 0.71,
        "historical_incident_count": 3,
        "lat": 27.0844,
        "lng": 93.6053,
    },
    "West Garo Hills": {
        "state": "Meghalaya",
        "rainfall_24h_mm": 45.0,
        "rainfall_72h_mm": 95.0,
        "rainfall_7d_mm": 180.0,
        "slope_avg_degrees": 22.0,
        "elevation_m": 350.0,
        "soil_saturation_index": 0.35,
        "historical_incident_count": 1,
        "lat": 25.5141,
        "lng": 90.2032,
    },
    "Dima Hasao": {
        "state": "Assam",
        "rainfall_24h_mm": 195.0,
        "rainfall_72h_mm": 390.0,
        "rainfall_7d_mm": 780.0,
        "slope_avg_degrees": 41.0,
        "elevation_m": 513.0,
        "soil_saturation_index": 0.85,
        "historical_incident_count": 9,
        "lat": 25.1764,
        "lng": 93.0158,
    },
}

_LEVEL_MAPPING = {
    0: RiskLevel.LOW,
    1: RiskLevel.MEDIUM,
    2: RiskLevel.HIGH,
    3: RiskLevel.VERY_HIGH,
}


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
        self._model = None
        self._load_model()

    def _load_model(self):
        if os.path.exists(MODEL_PATH):
            try:
                self._model = joblib.load(MODEL_PATH)
                print(f"[ML Engine] Loaded trained risk model from {MODEL_PATH}")
            except Exception as e:
                print(f"[ML Engine] Failed to load model from {MODEL_PATH}: {e}")
        else:
            print(f"[ML Engine] Model file not found at {MODEL_PATH}. Will fallback to heuristic ML rules.")

    def get_district_heatmap(self) -> list[DistrictRisk]:
        """Runs ML model inference over latest NER district features."""
        now = datetime.now(timezone.utc)
        results = []
        for name, profile in _NER_DISTRICT_PROFILES.items():
            risk_res = self._predict_profile(name, profile, now)
            results.append(risk_res)
        return results

    def predict_district_risk(self, district: str) -> DistrictRisk:
        """Runs ML model inference for a single district."""
        now = datetime.now(timezone.utc)
        profile = _NER_DISTRICT_PROFILES.get(district)
        if not profile:
            profile = {
                "state": "NER Region",
                "rainfall_24h_mm": 80.0,
                "rainfall_72h_mm": 160.0,
                "rainfall_7d_mm": 320.0,
                "slope_avg_degrees": 30.0,
                "elevation_m": 800.0,
                "soil_saturation_index": 0.5,
                "historical_incident_count": 2,
            }
        return self._predict_profile(district, profile, now)

    def _predict_profile(self, district: str, profile: dict, now: datetime) -> DistrictRisk:
        feature_cols = [
            "rainfall_24h_mm",
            "rainfall_72h_mm",
            "rainfall_7d_mm",
            "slope_avg_degrees",
            "elevation_m",
            "soil_saturation_index",
            "historical_incident_count",
        ]
        df_input = pd.DataFrame([{col: profile[col] for col in feature_cols}])

        if self._model is not None:
            try:
                pred_class = int(self._model.predict(df_input)[0])
                risk_level = _LEVEL_MAPPING.get(pred_class, RiskLevel.LOW)

                if hasattr(self._model, "predict_proba"):
                    probs = self._model.predict_proba(df_input)[0]
                    # Score is weighted sum of probabilities
                    weights = [0.1, 0.4, 0.7, 0.95]
                    risk_score = float(sum(p * w for p, w in zip(probs, weights)))
                else:
                    risk_score = (pred_class + 1) * 0.25
            except Exception as e:
                print(f"[ML Engine] Prediction error for {district}: {e}")
                risk_score = 0.5
                risk_level = score_to_level(risk_score)
        else:
            score = (
                0.3 * (profile["rainfall_72h_mm"] / 400.0)
                + 0.3 * (profile["slope_avg_degrees"] / 60.0)
                + 0.2 * profile["soil_saturation_index"]
                + 0.2 * (profile["historical_incident_count"] / 10.0)
            )
            risk_score = min(1.0, max(0.0, float(score)))
            risk_level = score_to_level(risk_score)

        return DistrictRisk(
            district=district,
            state=profile["state"],
            risk_level=risk_level,
            risk_score=round(risk_score, 3),
            rainfall_mm_24h=profile["rainfall_24h_mm"],
            slope_avg_degrees=profile["slope_avg_degrees"],
            updated_at=now,
        )


risk_service = RiskService()
