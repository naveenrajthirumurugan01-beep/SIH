"""
Temporal Step Engine - Advances digital twin zone states forward across time horizons
t0, t+1h, t+3h, t+6h, t+12h, t+24h.
"""

from dataclasses import dataclass
from typing import Dict, Any, List
from digital_twin.models.terrain_state.terrain_model import TerrainState
from digital_twin.models.rainfall.rainfall_model import RainfallState
from digital_twin.models.hydrology.hydrology_model import HydrologyState
from digital_twin.models.geotechnical.geotechnical_model import GeotechnicalState
from digital_twin.models.displacement.displacement_model import DisplacementState
from digital_twin.models.instability.instability_model import InstabilityState
from digital_twin.simulation.scenarios.scenario_definitions import SimulationScenario

@dataclass
class ZoneSnapshot:
    timestep_name: str         # t0, t+1h, t+3h, t+6h, t+12h, t+24h
    elapsed_hours: float
    terrain: TerrainState
    rainfall: RainfallState
    hydrology: HydrologyState
    geotechnical: GeotechnicalState
    displacement: DisplacementState
    instability: InstabilityState
    effective_stress_kpa: float

    def to_dict(self) -> Dict[str, Any]:
        return {
            "timestep_name": self.timestep_name,
            "elapsed_hours": self.elapsed_hours,
            "rainfall_intensity": self.rainfall.rainfall_intensity,
            "soil_saturation": self.hydrology.saturation,
            "pore_water_pressure": self.hydrology.pore_water_pressure,
            "effective_stress_kpa": self.effective_stress_kpa,
            "factor_of_safety": self.instability.factor_of_safety,
            "displacement": self.displacement.displacement,
            "displacement_velocity": self.displacement.displacement_velocity,
            "displacement_acceleration": self.displacement.displacement_acceleration,
            "movement_trend": self.displacement.movement_trend,
            "risk_score": self.instability.risk_score,
            "risk_level": self.instability.risk_level,
            "landslide_flag": self.instability.landslide_flag
        }

class TemporalEngine:
    TIMESTEPS = [
        ("t0", 0.0),
        ("t+1h", 1.0),
        ("t+3h", 3.0),
        ("t+6h", 6.0),
        ("t+12h", 12.0),
        ("t+24h", 24.0)
    ]

    @classmethod
    def simulate_zone_evolution(
        cls,
        initial_data: Dict[str, Any],
        scenario: SimulationScenario,
        target_horizon_hours: float = 6.0
    ) -> List[ZoneSnapshot]:
        """
        Runs time-series simulation for a single zone from t0 up to target horizon.
        """
        terrain = TerrainState(
            zone_id=initial_data["zone_id"],
            location_name=initial_data.get("location_name", "Dibang Valley Zone"),
            latitude=initial_data["latitude"],
            longitude=initial_data["longitude"],
            elevation=initial_data.get("elevation", 1500.0),
            slope_angle=initial_data.get("slope_angle", 45.0),
            aspect=initial_data.get("aspect", 180.0),
            slope_height=initial_data.get("slope_height", 25.0),
            geology=initial_data.get("geology", "Schist & Colluvium"),
            historical_landslide_indicator=initial_data.get("historical_landslide_indicator", False),
            distance_from_incident=initial_data.get("distance_from_current_incident", 0.0)
        )

        rainfall = RainfallState(
            rainfall_intensity=initial_data.get("rainfall_intensity", 15.0),
            hourly_rainfall=initial_data.get("hourly_rainfall", 15.0),
            cumulative_rainfall=initial_data.get("cumulative_rainfall", 80.0),
            antecedent_rainfall=initial_data.get("antecedent_rainfall", 60.0),
            rainfall_duration=initial_data.get("rainfall_duration", 12.0),
            forecast_rainfall=initial_data.get("forecast_rainfall", 20.0)
        )

        initial_sat = scenario.initial_saturation_override if scenario.initial_saturation_override is not None else initial_data.get("saturation", 0.70)
        hydrology = HydrologyState(
            soil_moisture=initial_sat * 0.45,
            saturation=initial_sat,
            permeability=initial_data.get("permeability", 0.018),
            pore_water_pressure=initial_data.get("pore_water_pressure", 35.0),
            infiltration_state=initial_data.get("infiltration_state", "moderate")
        )

        geotechnical = GeotechnicalState(
            density=initial_data.get("density", 1.3),
            cohesion=initial_data.get("cohesion", 30.0),
            friction_angle=initial_data.get("friction_angle", 30.0),
            poisson_ratio=initial_data.get("poisson_ratio", 0.30),
            deformation_modulus=initial_data.get("deformation_modulus", 30.0)
        )

        init_accel = initial_data.get("displacement_acceleration", 0.1) * scenario.displacement_accel_multiplier
        displacement = DisplacementState(
            displacement=initial_data.get("displacement", 5.0),
            displacement_velocity=initial_data.get("displacement_velocity", 0.5),
            displacement_acceleration=init_accel,
            sensor_status=initial_data.get("sensor_status", "ONLINE_ACTIVE")
        )

        snapshots: List[ZoneSnapshot] = []
        curr_rainfall = rainfall
        curr_hydrology = hydrology
        curr_displacement = displacement
        last_hours = 0.0

        for t_name, t_hours in cls.TIMESTEPS:
            if t_hours > target_horizon_hours and snapshots:
                break

            dt = t_hours - last_hours if t_hours > 0 else 0.0

            if dt > 0:
                # Evolve fields
                curr_rainfall = curr_rainfall.evolve_rainfall(dt, scenario.rainfall_multiplier)
                q_infiltrate = curr_rainfall.calculate_surface_infiltration(terrain.slope_angle)
                curr_hydrology = curr_hydrology.update_hydrology(q_infiltrate, dt, terrain.slope_angle, terrain.slope_height)

                fs = geotechnical.calculate_factor_of_safety(
                    curr_hydrology.pore_water_pressure,
                    curr_hydrology.saturation,
                    terrain.slope_angle,
                    depth_m=5.0
                )
                curr_displacement = curr_displacement.evolve_displacement(fs, dt, curr_hydrology.pore_water_pressure)
            else:
                fs = geotechnical.calculate_factor_of_safety(
                    curr_hydrology.pore_water_pressure,
                    curr_hydrology.saturation,
                    terrain.slope_angle,
                    depth_m=5.0
                )

            eff_stress = geotechnical.calculate_effective_stress(
                curr_hydrology.pore_water_pressure,
                curr_hydrology.saturation,
                terrain.slope_angle
            )

            instability = InstabilityState.evaluate_instability(
                factor_of_safety=fs,
                displacement_accel=curr_displacement.displacement_acceleration,
                saturation=curr_hydrology.saturation,
                slope_angle_deg=terrain.slope_angle,
                rainfall_intensity=curr_rainfall.rainfall_intensity,
                baseline_risk_score=initial_data.get("current_risk_score")
            )

            snapshot = ZoneSnapshot(
                timestep_name=t_name,
                elapsed_hours=t_hours,
                terrain=terrain,
                rainfall=curr_rainfall,
                hydrology=curr_hydrology,
                geotechnical=geotechnical,
                displacement=curr_displacement,
                instability=instability,
                effective_stress_kpa=eff_stress
            )
            snapshots.append(snapshot)
            last_hours = t_hours

        return snapshots
