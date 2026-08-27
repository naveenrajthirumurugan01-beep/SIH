"""
Terrain State Model - Represents geometry, slope aspect, elevation, and lithology.
Reference: Sensors 2026, 26, 421 (Slope Model Configuration)
"""

import math
from dataclasses import dataclass, field
from typing import Dict, Any

@dataclass
class TerrainState:
    zone_id: str
    location_name: str
    latitude: float
    longitude: float
    elevation: float            # meters
    slope_angle: float          # degrees (beta)
    aspect: float               # degrees
    slope_height: float         # meters (H)
    geology: str
    historical_landslide_indicator: bool
    distance_from_incident: float = 0.0

    @property
    def slope_radians(self) -> float:
        return math.radians(self.slope_angle)

    @property
    def toe_mutation_zone_height(self) -> float:
        """
        [RESEARCH-DERIVED] Sensors 2026, 26, 421:
        Identified mutation-sensitive zone at ~0.1 slope height above the toe (2-4m for 20m height).
        """
        return 0.10 * self.slope_height

    def to_dict(self) -> Dict[str, Any]:
        return {
            "zone_id": self.zone_id,
            "location_name": self.location_name,
            "latitude": self.latitude,
            "longitude": self.longitude,
            "elevation": self.elevation,
            "slope_angle": self.slope_angle,
            "aspect": self.aspect,
            "slope_height": self.slope_height,
            "distance_from_incident": self.distance_from_incident,
            "geology": self.geology,
            "historical_landslide_indicator": self.historical_landslide_indicator,
            "toe_mutation_zone_height": round(self.toe_mutation_zone_height, 2)
        }
