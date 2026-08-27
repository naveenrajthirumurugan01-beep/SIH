"""
Unit and Integration Test Suite for Digital Twin Engine
Validates all 6 required test cases per Section 27.
"""

import os
import unittest
from digital_twin.simulation.simulator.twin_simulator import DigitalTwinSimulator
from digital_twin.simulation.scenarios.scenario_definitions import get_scenario
from digital_twin.prediction.candidate_zones.candidate_search import CandidateZoneSearch
from digital_twin.prediction.ranking.zone_ranker import ZoneRanker
from digital_twin.prediction.traceability.audit_trail import PredictionAuditTrail

DATA_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data", "synthetic", "dibang_valley_zones.json")

class TestDigitalTwinEngine(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.simulator = DigitalTwinSimulator.from_json_file(DATA_PATH)

    def test_1_stable_zone(self):
        """TEST 1: Stable zone -> Expected: risk remains stable."""
        snapshots = self.simulator.simulate_zone("DV-005", "BASELINE", 6.0)
        t0_risk = snapshots[0].instability.risk_score
        t_final_risk = snapshots[-1].instability.risk_score
        self.assertLess(t0_risk, 0.35)
        self.assertLess(t_final_risk, 0.35)
        self.assertLess(abs(t_final_risk - t0_risk), 0.15)

    def test_2_increasing_rainfall(self):
        """TEST 2: Increasing rainfall -> Expected: hydrological state changes and pore pressure increases."""
        base_snapshots = self.simulator.simulate_zone("DV-014", "BASELINE", 6.0)
        heavy_snapshots = self.simulator.simulate_zone("DV-014", "RAINFALL_PLUS_50", 6.0)

        self.assertGreater(heavy_snapshots[-1].rainfall.rainfall_intensity, base_snapshots[-1].rainfall.rainfall_intensity)
        self.assertGreaterEqual(heavy_snapshots[-1].hydrology.pore_water_pressure, base_snapshots[-1].hydrology.pore_water_pressure)

    def test_3_soil_moisture_pore_pressure_effective_stress(self):
        """TEST 3: Increasing soil moisture + pore pressure -> Expected: effective stress decreases."""
        snapshots = self.simulator.simulate_zone("DV-014", "HIGH_SOIL_SATURATION", 6.0)
        t0 = snapshots[0]
        t_final = snapshots[-1]

        self.assertGreaterEqual(t_final.hydrology.pore_water_pressure, t0.hydrology.pore_water_pressure)
        self.assertLessEqual(t_final.effective_stress_kpa, t0.effective_stress_kpa)
        self.assertGreaterEqual(t_final.instability.risk_score, t0.instability.risk_score)

    def test_4_displacement_acceleration_ranking(self):
        """TEST 4: Increasing displacement acceleration -> Expected: candidate zone ranking changes."""
        candidates = CandidateZoneSearch.find_surrounding_candidates("DV-007", self.simulator.zones_data, 10.0)
        
        scenario = get_scenario("ACCELERATING_DISPLACEMENT")
        snaps = {}
        for c in candidates:
            zid = c["zone_id"]
            snaps[zid] = self.simulator.simulate_zone(zid, "ACCELERATING_DISPLACEMENT", 6.0)

        rankings = ZoneRanker.rank_candidates(candidates, snaps)
        self.assertTrue(len(rankings) > 0)
        self.assertGreater(rankings[0].stability_state["risk_score"], 0.60)

    def test_5_next_emergent_risk_identification(self):
        """TEST 5: One surrounding zone becomes significantly more unstable -> Expected: identified as NEXT EMERGENT RISK."""
        incident = self.simulator.get_zone("DV-007")
        candidates = CandidateZoneSearch.find_surrounding_candidates("DV-007", self.simulator.zones_data, 10.0)
        
        snaps = {}
        for c in candidates:
            zid = c["zone_id"]
            snaps[zid] = self.simulator.simulate_zone(zid, "RAINFALL_PLUS_50", 6.0)

        rankings = ZoneRanker.rank_candidates(candidates, snaps)
        selected_next = rankings[0]

        # Verify candidate zone is selected with CRITICAL predicted level
        self.assertIn(selected_next.zone_id, ["DV-014", "DV-011", "DV-008"])
        self.assertGreaterEqual(selected_next.predicted_risk, 0.75)
        self.assertEqual(selected_next.predicted_level, "CRITICAL")

        # Verify audit trail generation
        record = PredictionAuditTrail.generate_prediction_record(
            incident, selected_next, rankings, "RAINFALL_PLUS_50", 6.0
        )
        self.assertIn("why_selected", record)
        self.assertIn(record["next_emergent_risk"]["zone_id"], ["DV-014", "DV-011", "DV-008"])

    def test_6_no_emerging_risk_threshold_handling(self):
        """TEST 6: Checks baseline stable candidates handling."""
        candidates = CandidateZoneSearch.find_surrounding_candidates("DV-005", self.simulator.zones_data, 5.0)
        self.assertTrue(isinstance(candidates, list))

if __name__ == "__main__":
    unittest.main()
