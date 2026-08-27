"""
Displacement Model - Kinematic movement, velocity, acceleration & movement trends.
Reference: Sensors 2026, 26, 421 (Displacement mutation sensitive zone & time scales)
"""

from dataclasses import dataclass
from typing import Dict, Any, Tuple

@dataclass
class DisplacementState:
    displacement: float             # Total displacement delta (mm)
    displacement_velocity: float    # v_disp (mm/h)
    displacement_acceleration: float # a_disp (mm/h^2)
    sensor_status: str              # ONLINE_ACTIVE, SIMULATED, etc.

    @property
    def movement_trend(self) -> str:
        """
        Calculates movement trend classification:
        STABLE, INCREASING, ACCELERATING, RAPIDLY_ACCELERATING
        """
        a = self.displacement_acceleration
        v = self.displacement_velocity
        if a > 2.0 or v > 3.0:
            return "RAPIDLY_ACCELERATING"
        elif a > 0.5 or v > 1.0:
            return "ACCELERATING"
        elif a > 0.0 or v > 0.2:
            return "INCREASING"
        else:
            return "STABLE"

    def evolve_displacement(
        self,
        fs: float,
        dt_hours: float,
        pore_pressure_kpa: float
    ) -> 'DisplacementState':
        """
        Advances displacement kinematics based on Factor of Safety (Fs) and pore-pressure.
        When Fs < 1.3, velocity and acceleration increase nonlinearly.
        """
        # Acceleration driving term based on strength deficit
        if fs < 1.0:
            new_accel = self.displacement_acceleration + (1.0 - fs) * 3.5 * dt_hours + (pore_pressure_kpa * 0.02)
        elif fs < 1.3:
            new_accel = self.displacement_acceleration + (1.3 - fs) * 1.2 * dt_hours
        else:
            new_accel = max(0.0, self.displacement_acceleration - 0.2 * dt_hours)

        new_velocity = max(0.0, self.displacement_velocity + new_accel * dt_hours)
        new_displacement = self.displacement + new_velocity * dt_hours

        return DisplacementState(
            displacement=round(new_displacement, 2),
            displacement_velocity=round(new_velocity, 2),
            displacement_acceleration=round(new_accel, 2),
            sensor_status=self.sensor_status
        )

    def to_dict(self) -> Dict[str, Any]:
        return {
            "displacement": self.displacement,
            "displacement_velocity": self.displacement_velocity,
            "displacement_acceleration": self.displacement_acceleration,
            "movement_trend": self.movement_trend,
            "sensor_status": self.sensor_status
        }
