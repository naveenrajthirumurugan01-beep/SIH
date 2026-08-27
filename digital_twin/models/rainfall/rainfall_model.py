"""
Rainfall Model - Current intensity, duration, antecedent accumulation & scenario projections.
Reference: Sensors 2026, 26, 421 (Surface Pore Flow q = I * cos(beta))
"""

import math
from dataclasses import dataclass
from typing import Dict, Any

@dataclass
class RainfallState:
    rainfall_intensity: float    # mm/h (or m/h in paper)
    hourly_rainfall: float       # mm
    cumulative_rainfall: float   # mm over event
    antecedent_rainfall: float   # mm over 72h
    rainfall_duration: float     # hours
    forecast_rainfall: float     # mm next horizon

    @property
    def intensity_m_per_h(self) -> float:
        """Converts mm/h to m/h."""
        return self.rainfall_intensity / 1000.0

    def calculate_surface_infiltration(self, slope_angle_deg: float) -> float:
        """
        [RESEARCH-DERIVED] Sensors 2026 Section 2.4.4:
        Surface pore flow = -0.02 * cos(beta) for extreme rainstorm intensity 0.02 m/h.
        Returns infiltration rate q in m/h.
        """
        beta_rad = math.radians(slope_angle_deg)
        return self.intensity_m_per_h * math.cos(beta_rad)

    def evolve_rainfall(self, dt_hours: float, scenario_multiplier: float = 1.0) -> 'RainfallState':
        """Advances rainfall state over dt_hours."""
        effective_intensity = self.rainfall_intensity * scenario_multiplier
        added_rain = effective_intensity * dt_hours
        return RainfallState(
            rainfall_intensity=effective_intensity,
            hourly_rainfall=effective_intensity,
            cumulative_rainfall=self.cumulative_rainfall + added_rain,
            antecedent_rainfall=self.antecedent_rainfall + added_rain * 0.8,
            rainfall_duration=self.rainfall_duration + dt_hours,
            forecast_rainfall=max(0.0, self.forecast_rainfall - added_rain)
        )

    def to_dict(self) -> Dict[str, Any]:
        return {
            "rainfall_intensity": round(self.rainfall_intensity, 2),
            "hourly_rainfall": round(self.hourly_rainfall, 2),
            "cumulative_rainfall": round(self.cumulative_rainfall, 2),
            "antecedent_rainfall": round(self.antecedent_rainfall, 2),
            "rainfall_duration": round(self.rainfall_duration, 2),
            "forecast_rainfall": round(self.forecast_rainfall, 2)
        }
