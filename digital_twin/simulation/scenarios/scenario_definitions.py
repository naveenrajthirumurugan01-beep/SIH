"""
Scenario Definitions - Defines simulation scenarios for what-if digital twin experiments.
"""

from dataclasses import dataclass
from typing import Dict, Any

@dataclass
class SimulationScenario:
    name: str
    description: str
    rainfall_multiplier: float
    initial_saturation_override: float = None
    displacement_accel_multiplier: float = 1.0

SCENARIOS: Dict[str, SimulationScenario] = {
    "BASELINE": SimulationScenario(
        name="BASELINE",
        description="Current observed meteorological and environmental conditions.",
        rainfall_multiplier=1.0
    ),
    "RAINFALL_PLUS_20": SimulationScenario(
        name="RAINFALL_PLUS_20",
        description="Rainfall intensity increased by +20%.",
        rainfall_multiplier=1.20
    ),
    "RAINFALL_PLUS_50": SimulationScenario(
        name="RAINFALL_PLUS_50",
        description="Rainfall intensity increased by +50% (Severe Rainstorm).",
        rainfall_multiplier=1.50
    ),
    "HIGH_SOIL_SATURATION": SimulationScenario(
        name="HIGH_SOIL_SATURATION",
        description="Pre-conditioned high soil saturation state (Sw = 0.92).",
        rainfall_multiplier=1.10,
        initial_saturation_override=0.92
    ),
    "ACCELERATING_DISPLACEMENT": SimulationScenario(
        name="ACCELERATING_DISPLACEMENT",
        description="Simulated ground movement acceleration on slope toe.",
        rainfall_multiplier=1.15,
        displacement_accel_multiplier=1.80
    ),
    "EXTREME_RAINstorm": SimulationScenario(
        name="EXTREME_RAINstorm",
        description="Extreme rainstorm benchmark event (0.02 m/h per Sensors 2026 paper).",
        rainfall_multiplier=2.00,
        initial_saturation_override=0.95,
        displacement_accel_multiplier=2.20
    )
}

def get_scenario(scenario_key: str) -> SimulationScenario:
    return SCENARIOS.get(scenario_key.upper(), SCENARIOS["BASELINE"])
