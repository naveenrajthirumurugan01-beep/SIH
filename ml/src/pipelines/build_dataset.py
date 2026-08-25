"""Merge terrain, rainfall, and historical incident sources into one training table.

TODO:
1. Load terrain features per district (src/features/terrain_features.py)
2. Load rolling rainfall features per district (src/features/rainfall_features.py)
3. Load historical landslide incident records (ml/data/raw/) and label past
   events with the risk level that materialized
4. Join all three on (district, date) and write to
   ml/data/processed/training_dataset.csv
"""


def build_dataset() -> None:
    raise NotImplementedError


if __name__ == "__main__":
    build_dataset()
