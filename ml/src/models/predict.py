"""Inference helper that loads the trained model and scores a feature row.

Used by backend/app/services/risk_service.py (directly, or via a shared
package install) to turn engineered features into a risk score/level.
"""

import joblib
import pandas as pd

from src.models.train import FEATURE_COLUMNS, MODEL_OUTPUT_PATH

RISK_LEVELS = ["low", "medium", "high", "very_high"]


def load_model(path: str = MODEL_OUTPUT_PATH):
    return joblib.load(path)


def predict_risk(model, features: dict) -> dict:
    """features: dict matching FEATURE_COLUMNS. Returns {level, score, probabilities}."""
    row = pd.DataFrame([{col: features[col] for col in FEATURE_COLUMNS}])
    proba = model.predict_proba(row)[0]
    predicted_class = int(proba.argmax())
    return {
        "level": RISK_LEVELS[predicted_class],
        "score": float(proba[predicted_class]),
        "probabilities": dict(zip(RISK_LEVELS, proba.tolist())),
    }
