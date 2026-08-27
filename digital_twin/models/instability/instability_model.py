"""
Instability & Unified Risk Model - Calculates Risk Index (0.0 to 1.0) and Risk Levels.
"""

from dataclasses import dataclass
from typing import Dict, Any

@dataclass
class InstabilityState:
    factor_of_safety: float
    risk_score: float         # 0.00 to 1.00
    risk_level: str           # LOW, MODERATE, HIGH, CRITICAL
    landslide_flag: bool

    @staticmethod
    def calculate_risk_level(risk_score: float) -> str:
        """
        Configurable risk level threshold mapping:
        0.00 - 0.25: LOW
        0.25 - 0.50: MODERATE
        0.50 - 0.75: HIGH
        0.75 - 1.00: CRITICAL
        """
        if risk_score >= 0.75:
            return "CRITICAL"
        elif risk_score >= 0.50:
            return "HIGH"
        elif risk_score >= 0.25:
            return "MODERATE"
        else:
            return "LOW"

    @classmethod
    def evaluate_instability(
        cls,
        factor_of_safety: float,
        displacement_accel: float,
        saturation: float,
        slope_angle_deg: float,
        rainfall_intensity: float,
        baseline_risk_score: float = None
    ) -> 'InstabilityState':
        """
        Unified multi-field risk scoring formula:
        Combines Factor of Safety, Kinematic Acceleration, Soil Saturation & Rainfall.
        """
        # 1. Fs score contribution (Fs <= 1.0 -> 1.0 risk, Fs >= 2.0 -> 0.0 risk)
        if factor_of_safety <= 1.0:
            fs_risk = 1.0
        elif factor_of_safety >= 2.0:
            fs_risk = 0.0
        else:
            fs_risk = (2.0 - factor_of_safety) / 1.0

        # 2. Kinematic acceleration contribution (accel >= 2.0 mm/h^2 -> 1.0)
        accel_risk = min(1.0, max(0.0, displacement_accel / 2.0))

        # 3. Saturation contribution
        sat_risk = saturation

        # 4. Slope / Rainfall intensity ratio (benchmark 20 mm/h per paper)
        rain_risk = min(1.0, max(0.0, rainfall_intensity / 20.0))

        raw_calc_risk = (0.50 * fs_risk) + (0.25 * accel_risk) + (0.15 * sat_risk) + (0.10 * rain_risk)

        if baseline_risk_score is not None:
            # Anchor to baseline risk score for initial t0 state and add physical delta
            delta = (raw_calc_risk - 0.40) * 0.40
            final_risk = round(min(1.0, max(0.0, baseline_risk_score + delta)), 2)
        else:
            final_risk = round(min(1.0, max(0.0, raw_calc_risk)), 2)

        level = cls.calculate_risk_level(final_risk)
        flag = final_risk >= 0.75 or factor_of_safety < 1.05

        return InstabilityState(
            factor_of_safety=round(factor_of_safety, 3),
            risk_score=final_risk,
            risk_level=level,
            landslide_flag=flag
        )

    def to_dict(self) -> Dict[str, Any]:
        return {
            "factor_of_safety": self.factor_of_safety,
            "risk_score": self.risk_score,
            "risk_level": self.risk_level,
            "landslide_flag": self.landslide_flag
        }
