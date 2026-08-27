"""
Twin Simulator Orchestrator - Main Digital Twin simulation orchestrator.
Manages multi-zone scenario simulation, temporal evolution, and state generation.
"""

import json
from typing import Dict, Any, List, Optional
from digital_twin.simulation.scenarios.scenario_definitions import get_scenario, SimulationScenario
from digital_twin.simulation.timestep_engine.temporal_engine import TemporalEngine, ZoneSnapshot

class DigitalTwinSimulator:
    def __init__(self, zones_data: List[Dict[str, Any]]):
        self.zones_data = zones_data
        self.zones_by_id = {z["zone_id"]: z for z in zones_data}

    @classmethod
    def from_json_file(cls, filepath: str) -> 'DigitalTwinSimulator':
        with open(filepath, 'r', encoding='utf-8') as f:
            data = json.load(f)
        return cls(data)

    def get_zone(self, zone_id: str) -> Optional[Dict[str, Any]]:
        return self.zones_by_id.get(zone_id)

    def simulate_zone(
        self,
        zone_id: str,
        scenario_key: str = "BASELINE",
        horizon_hours: float = 6.0
    ) -> List[ZoneSnapshot]:
        zone_data = self.get_zone(zone_id)
        if not zone_data:
            raise ValueError(f"Zone ID '{zone_id}' not found in simulator dataset.")

        scenario = get_scenario(scenario_key)
        return TemporalEngine.simulate_zone_evolution(zone_data, scenario, horizon_hours)

    def simulate_all_zones(
        self,
        scenario_key: str = "BASELINE",
        horizon_hours: float = 6.0
    ) -> Dict[str, List[ZoneSnapshot]]:
        results = {}
        scenario = get_scenario(scenario_key)
        for z in self.zones_data:
            zid = z["zone_id"]
            results[zid] = TemporalEngine.simulate_zone_evolution(z, scenario, horizon_hours)
        return results
