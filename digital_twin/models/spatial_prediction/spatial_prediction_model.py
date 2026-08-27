"""
Spatial Prediction Model - Spatial neighborhood search & distance calculation.
Computes Haversine distance and spatial candidate bounds.
"""

import math
from typing import Tuple

def haversine_distance_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculates Haversine distance in km between two lat/lon points."""
    R = 6371.0  # Earth radius in km
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (math.sin(dlat / 2) ** 2) + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * (math.sin(dlon / 2) ** 2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return round(R * c, 2)
