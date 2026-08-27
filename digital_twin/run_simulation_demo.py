"""
Standalone Executable Simulation Demonstration Script for Digital Twin Engine
Run independently via: python digital_twin/run_simulation_demo.py
"""

import os
import sys
import json

# Ensure project root is in sys.path
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

from digital_twin.simulation.simulator.twin_simulator import DigitalTwinSimulator
from digital_twin.simulation.scenarios.scenario_definitions import get_scenario
from digital_twin.prediction.candidate_zones.candidate_search import CandidateZoneSearch
from digital_twin.prediction.ranking.zone_ranker import ZoneRanker
from digital_twin.prediction.traceability.audit_trail import PredictionAuditTrail
from digital_twin.gis.geojson.geojson_exporter import GeoJSONExporter

def main():
    print("=" * 70)
    print("      DIGITAL TWIN ENGINE FOR LANDSLIDE EARLY-WARNING (DIBANG VALLEY)")
    print("=" * 70)

    data_path = os.path.join(PROJECT_ROOT, "digital_twin", "data", "synthetic", "dibang_valley_zones.json")
    print(f"\n[1/5] Ingesting Synthetic Field Dataset: {data_path}")

    simulator = DigitalTwinSimulator.from_json_file(data_path)
    print(f"      Loaded {len(simulator.zones_data)} Dibang Valley terrain zones successfully.")

    incident_id = "DV-007"
    scenario_key = "RAINFALL_PLUS_50"
    horizon_hours = 6.0
    search_radius_km = 10.0

    incident_zone = simulator.get_zone(incident_id)
    if not incident_zone:
        print(f"Error: Incident zone {incident_id} not found.")
        return

    print(f"\n[2/5] Initializing Digital Twin State for Incident Zone: {incident_id}")
    print(f"      Location: {incident_zone['location_name']}")
    print(f"      Current Risk: {incident_zone['current_risk_score']} ({incident_zone['current_risk_level']})")
    print(f"      Simulation Scenario: {scenario_key} (+50% Rainfall Intensity)")
    print(f"      Forecast Horizon: +{horizon_hours} Hours")

    print(f"\n[3/5] Performing Spatial Candidate Neighborhood Search (Radius: {search_radius_km} km)...")
    candidates = CandidateZoneSearch.find_surrounding_candidates(incident_id, simulator.zones_data, search_radius_km)
    print(f"      Identified {len(candidates)} surrounding candidate zones (excluding incident {incident_id}).")

    print(f"\n[4/5] Executing Hydro-Mechanical Temporal Forward Simulator across Candidates...")
    candidates_snapshots = {}
    for c in candidates:
        zid = c["zone_id"]
        candidates_snapshots[zid] = simulator.simulate_zone(zid, scenario_key, horizon_hours)

    rankings = ZoneRanker.rank_candidates(candidates, candidates_snapshots)
    next_prone = rankings[0]  # Top candidate by dynamic emerging risk rank score

    # Generate Audit Record & GeoJSON
    audit_record = PredictionAuditTrail.generate_prediction_record(
        incident_zone, next_prone, rankings, scenario_key, horizon_hours
    )
    geojson_data = GeoJSONExporter.generate_geojson(
        incident_zone, next_prone.zone_id, [r.to_dict() for r in rankings]
    )

    # Write Outputs
    output_dir = os.path.join(PROJECT_ROOT, "digital_twin", "outputs")
    os.makedirs(os.path.join(output_dir, "simulations"), exist_ok=True)
    os.makedirs(os.path.join(output_dir, "predictions"), exist_ok=True)
    os.makedirs(os.path.join(output_dir, "reports"), exist_ok=True)

    pred_json_path = os.path.join(output_dir, "predictions", f"{audit_record['prediction_id']}.json")
    geojson_path = os.path.join(output_dir, "simulations", f"{audit_record['prediction_id']}.geojson")
    report_path = os.path.join(output_dir, "reports", "latest_prediction_report.txt")

    with open(pred_json_path, 'w', encoding='utf-8') as f:
        json.dump(audit_record, f, indent=2)

    with open(geojson_path, 'w', encoding='utf-8') as f:
        json.dump(geojson_data, f, indent=2)

    # Print Formatted Section 29 Output
    output_text = f"""
--------------------------------------------------
DIGITAL TWIN SIMULATION RESULT
--------------------------------------------------

Source Incident:
{incident_id} ({incident_zone['location_name']})

Current Risk:
{incident_zone['current_risk_score']} — {incident_zone['current_risk_level']}

Simulation Horizon:
{int(horizon_hours)} HOURS (Scenario: {scenario_key})

--------------------------------------------------
NEXT EMERGENT RISK
--------------------------------------------------

Zone:
{next_prone.zone_id} ({next_prone.location_name})

Current Risk:
{next_prone.current_risk} — {next_prone.current_level}

Predicted Risk:
{next_prone.predicted_risk} — {next_prone.predicted_level}

Risk Increase:
+{round(next_prone.risk_change, 2)}

Distance from Incident:
{next_prone.distance_km} km

Prediction Horizon:
{next_prone.prediction_horizon}

--------------------------------------------------
WHY WAS THIS ZONE SELECTED? (TRACEABILITY)
--------------------------------------------------
"""
    for why_line in audit_record["why_selected"]:
        output_text += f"\n{why_line}"

    output_text += f"""

--------------------------------------------------
PHYSICAL CAUSALITY CHAIN
--------------------------------------------------
"""
    for idx, step in enumerate(audit_record["physical_causality_chain"], 1):
        output_text += f"\n  [{idx}] {step}"

    output_text += f"""

--------------------------------------------------
Simulation Status:
{audit_record['simulation_status']}

Validation Status:
{audit_record['validation_status']}
--------------------------------------------------
"""

    print(output_text)

    with open(report_path, 'w', encoding='utf-8') as f:
        f.write(output_text)

    print(f"\n[5/5] Artifacts Exported Successfully:")
    print(f"      - Audit JSON: {pred_json_path}")
    print(f"      - GeoJSON GIS: {geojson_path}")
    print(f"      - Summary Report: {report_path}")
    print("=" * 70)
    print("               DIGITAL TWIN SIMULATION DEMO COMPLETE")
    print("=" * 70)

if __name__ == "__main__":
    main()
