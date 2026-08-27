"""
Hydrology Model - Infiltration, degree of soil saturation, and pore-water pressure.
Reference: Sensors 2026, 26, 421 (Hydro-mechanical coupling & seepage fields)
"""

import math
from dataclasses import dataclass
from typing import Dict, Any

@dataclass
class HydrologyState:
    soil_moisture: float         # Fraction 0.0 to 1.0 (volumetric water content)
    saturation: float            # Degree of saturation Sw (0.0 to 1.0)
    permeability: float          # m/h (Saturated permeability k_sat = 0.018 m/h per paper)
    pore_water_pressure: float   # u in kPa
    infiltration_state: str      # low, moderate, high_seepage, saturated

    def update_hydrology(
        self,
        infiltration_rate_m_h: float,
        dt_hours: float,
        slope_angle_deg: float,
        slope_height: float = 20.0
    ) -> 'HydrologyState':
        """
        Updates degree of saturation Sw and pore pressure u over timestep dt.
        [RESEARCH-DERIVED] Formulations based on pore fluid consolidation & Terzaghi stress buildup.
        """
        void_ratio_n = 0.5  # Initial void ratio e=1.0 -> n = 0.5 (Sensors 2026 Table 1)
        mantle_depth = 5.0  # Representative soil depth

        # Saturation rate of change dSw/dt
        d_saturation = (infiltration_rate_m_h / (void_ratio_n * mantle_depth)) * (1.0 - self.saturation) * dt_hours
        new_saturation = min(1.0, max(self.saturation, self.saturation + d_saturation))

        # Water pressure calculation u = rho_w * g * h_water * cos^2(beta)
        rho_w_g = 9.81  # kN/m^3
        beta_rad = math.radians(slope_angle_deg)
        water_head = new_saturation * mantle_depth
        new_pore_pressure = self.pore_water_pressure + (new_saturation - self.saturation) * rho_w_g * mantle_depth * (math.cos(beta_rad) ** 2)

        # Infiltration state label
        if new_saturation >= 0.90:
            state_label = "saturated"
        elif new_saturation >= 0.75:
            state_label = "high_seepage"
        elif new_saturation >= 0.50:
            state_label = "moderate"
        else:
            state_label = "low"

        return HydrologyState(
            soil_moisture=round(new_saturation * 0.45, 3), # Volumetric water content ~0.45 * Sw
            saturation=round(new_saturation, 3),
            permeability=self.permeability,
            pore_water_pressure=round(new_pore_pressure, 2),
            infiltration_state=state_label
        )

    def to_dict(self) -> Dict[str, Any]:
        return {
            "soil_moisture": self.soil_moisture,
            "saturation": self.saturation,
            "permeability": self.permeability,
            "pore_water_pressure": self.pore_water_pressure,
            "infiltration_state": self.infiltration_state
        }
