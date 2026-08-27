"""
Geotechnical Model - Effective Stress (sigma' = sigma - u) & Mohr-Coulomb Shear Strength.
Reference: Sensors 2026, 26, 421 (Key soil parameter configuration Table 1)
"""

import math
from dataclasses import dataclass
from typing import Dict, Any

@dataclass
class GeotechnicalState:
    density: float             # Dry density gamma_dry = 1.3 g/cm^3 = 12.75 kN/m^3
    cohesion: float            # Effective cohesion c' (kPa): 15-40 kPa
    friction_angle: float      # Effective friction angle phi' = 30.0 deg
    poisson_ratio: float       # nu = 0.30
    deformation_modulus: float # E = 30 MPa

    def calculate_effective_stress(
        self,
        pore_water_pressure_kpa: float,
        saturation: float,
        slope_angle_deg: float,
        depth_m: float = 5.0
    ) -> float:
        """
        [RESEARCH-DERIVED] Terzaghi Effective Stress: sigma' = sigma - u
        sigma = total normal stress under self-weight + saturation.
        """
        gamma_dry_kn = self.density * 9.81  # ~12.75 kN/m^3
        void_ratio_n = 0.5
        gamma_sat_kn = gamma_dry_kn + saturation * void_ratio_n * 9.81  # Unit weight

        beta_rad = math.radians(slope_angle_deg)
        total_normal_stress = gamma_sat_kn * depth_m * (math.cos(beta_rad) ** 2)

        effective_stress = max(0.1, total_normal_stress - pore_water_pressure_kpa)
        return round(effective_stress, 2)

    def calculate_shear_strength(self, effective_stress_kpa: float) -> float:
        """
        [RESEARCH-DERIVED] Mohr-Coulomb Shear Strength: tau = c' + sigma' * tan(phi)
        """
        phi_rad = math.radians(self.friction_angle)
        tau = self.cohesion + effective_stress_kpa * math.tan(phi_rad)
        return round(tau, 2)

    def calculate_driving_stress(
        self,
        saturation: float,
        slope_angle_deg: float,
        depth_m: float = 5.0
    ) -> float:
        """
        Downward driving shear stress tau_d = gamma_sat * z * sin(beta) * cos(beta)
        """
        gamma_dry_kn = self.density * 9.81
        void_ratio_n = 0.5
        gamma_sat_kn = gamma_dry_kn + saturation * void_ratio_n * 9.81

        beta_rad = math.radians(slope_angle_deg)
        tau_driving = gamma_sat_kn * depth_m * math.sin(beta_rad) * math.cos(beta_rad)
        return round(max(0.1, tau_driving), 2)

    def calculate_factor_of_safety(
        self,
        pore_water_pressure_kpa: float,
        saturation: float,
        slope_angle_deg: float,
        depth_m: float = 5.0
    ) -> float:
        """
        Factor of Safety (Fs) = Available Shear Strength / Downward Driving Stress
        """
        sigma_prime = self.calculate_effective_stress(pore_water_pressure_kpa, saturation, slope_angle_deg, depth_m)
        tau_avail = self.calculate_shear_strength(sigma_prime)
        tau_drive = self.calculate_driving_stress(saturation, slope_angle_deg, depth_m)

        fs = tau_avail / tau_drive
        return round(fs, 3)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "density": self.density,
            "cohesion": self.cohesion,
            "friction_angle": self.friction_angle,
            "poisson_ratio": self.poisson_ratio,
            "deformation_modulus": self.deformation_modulus
        }
