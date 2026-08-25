"""Train the landslide risk classifier.

Primary: XGBoost/LightGBM gradient-boosted trees on terrain + rainfall +
historical incident features. Falls back to scikit-learn (RandomForest) if
neither boosting library is available in the environment.

TODO: replace the synthetic dataset with the merged terrain/rainfall/
historical-incident feature table once ml/src/pipelines/build_dataset.py
is implemented.

Usage:
    python -m src.models.train
"""

import joblib
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split

FEATURE_COLUMNS = [
    "rainfall_24h_mm",
    "rainfall_72h_mm",
    "rainfall_7d_mm",
    "slope_avg_degrees",
    "elevation_m",
    "soil_saturation_index",
    "historical_incident_count",
]
TARGET_COLUMN = "risk_label"  # 0=low, 1=medium, 2=high, 3=very_high

MODEL_OUTPUT_PATH = "ml/models/risk_model.joblib"


def _get_model():
    try:
        from xgboost import XGBClassifier

        return XGBClassifier(
            n_estimators=200,
            max_depth=5,
            learning_rate=0.05,
            objective="multi:softprob",
            num_class=4,
        )
    except ImportError:
        pass

    try:
        from lightgbm import LGBMClassifier

        return LGBMClassifier(n_estimators=200, max_depth=5, learning_rate=0.05)
    except ImportError:
        pass

    from sklearn.ensemble import RandomForestClassifier

    return RandomForestClassifier(n_estimators=200, max_depth=8)


def _load_dataset() -> pd.DataFrame:
    """TODO: replace with ml/data/processed/training_dataset.csv produced by
    src/pipelines/build_dataset.py. Synthetic placeholder unblocks the
    scaffold in the meantime."""
    rng = np.random.default_rng(seed=42)
    n = 500
    df = pd.DataFrame(
        {
            "rainfall_24h_mm": rng.uniform(0, 200, n),
            "rainfall_72h_mm": rng.uniform(0, 400, n),
            "rainfall_7d_mm": rng.uniform(0, 800, n),
            "slope_avg_degrees": rng.uniform(0, 60, n),
            "elevation_m": rng.uniform(50, 2500, n),
            "soil_saturation_index": rng.uniform(0, 1, n),
            "historical_incident_count": rng.poisson(1, n),
        }
    )
    score = (
        0.3 * (df["rainfall_72h_mm"] / 400)
        + 0.3 * (df["slope_avg_degrees"] / 60)
        + 0.2 * df["soil_saturation_index"]
        + 0.2 * (df["historical_incident_count"] / df["historical_incident_count"].max())
    )
    df[TARGET_COLUMN] = pd.cut(score, bins=4, labels=[0, 1, 2, 3]).astype(int)
    return df


def train():
    df = _load_dataset()
    X = df[FEATURE_COLUMNS]
    y = df[TARGET_COLUMN]

    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    model = _get_model()
    model.fit(X_train, y_train)

    accuracy = model.score(X_test, y_test)
    print(f"Holdout accuracy: {accuracy:.3f}")

    joblib.dump(model, MODEL_OUTPUT_PATH)
    print(f"Model saved to {MODEL_OUTPUT_PATH}")


if __name__ == "__main__":
    train()
