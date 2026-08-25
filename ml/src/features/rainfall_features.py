"""Rainfall feature engineering from IMD/weather API time series data.

TODO: source live/historical rainfall for NER districts (IMD gridded data or
a weather API) and derive rolling features known to correlate with
landslide triggering (e.g. antecedent rainfall).
"""

import pandas as pd


def load_rainfall_timeseries(csv_path: str) -> pd.DataFrame:
    """TODO: expect columns [district, timestamp, rainfall_mm]."""
    return pd.read_csv(csv_path, parse_dates=["timestamp"])


def compute_rolling_rainfall(df: pd.DataFrame, windows_hours: list[int] | None = None) -> pd.DataFrame:
    """TODO: compute rolling sums (e.g. 24h, 72h, 7-day) per district —
    cumulative antecedent rainfall is a standard landslide trigger feature."""
    windows_hours = windows_hours or [24, 72, 168]
    raise NotImplementedError
