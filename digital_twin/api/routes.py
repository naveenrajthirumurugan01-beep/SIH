"""
API Routes for Digital Twin Engine
Provides REST API endpoints for simulation, prediction lookup, zone inspection, scenarios & health.
"""

import os
import json
from fastapi import APIRouter, HTTPException, Query
from typing import Dict, Any, List

from digital_twin.simulation.simulator.twin_simulator import DigitalTwinSimulator
from digital_twin.simulation.scenarios.scenario_definitions import SCENARIOS, get_scenario
from digital_twin.prediction.candidate_zones.candidate_search import CandidateZoneSearch
from digital_twin.prediction.ranking.zone_ranker import ZoneRanker
from digital_twin.prediction.traceability.audit_trail import PredictionAuditTrail
from digital_twin.gis.geojson.geojson_exporter import GeoJSONExporter
from digital_twin.validation.validator import DigitalTwinValidator
from digital_twin.api.schemas import SimulationRequest

router = APIRouter()

# Data path resolution
DATA_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data", "synthetic", "dibang_valley_zones.json")

# Memory store for past predictions
PREDICTION_HISTORY: Dict[str, Dict[str, Any]] = {}

def get_simulator() -> DigitalTwinSimulator:
    if not os.path.exists(DATA_PATH):
        raise HTTPException(status_code=500, detail=f"Synthetic dataset missing at {DATA_PATH}")
    return DigitalTwinSimulator.from_json_file(DATA_PATH)

@router.get("/health")
def get_health() -> Dict[str, Any]:
    return {
        "engine_status": "ONLINE_HEALTHY",
        "engine_name": "Dibang Valley Landslide Digital Twin Engine",
        "simulation_mode": "PHYSICS_INFORMED_HYDRO_MECHANICAL",
        "dataset": "dibang_valley_zones.json",
        "validation_status": "NOT YET VALIDATED WITH LOCAL FIELD OBSERVATIONS"
    }

@router.get("/scenarios")
def get_scenarios() -> Dict[str, Any]:
    return {
        "available_scenarios": [
            {
                "key": key,
                "name": sc.name,
                "description": sc.description,
                "rainfall_multiplier": sc.rainfall_multiplier
            }
            for key, sc in SCENARIOS.items()
        ]
    }

@router.get("/zones/{zone_id}")
def get_zone_state(zone_id: str, scenario_key: str = "BASELINE", horizon_hours: float = 6.0) -> Dict[str, Any]:
    sim = get_simulator()
    zone_data = sim.get_zone(zone_id)
    if not zone_data:
        raise HTTPException(status_code=404, detail=f"Zone '{zone_id}' not found.")

    snapshots = sim.simulate_zone(zone_id, scenario_key, horizon_hours)
    return {
        "zone_info": zone_data,
        "scenario": scenario_key,
        "horizon_hours": horizon_hours,
        "temporal_snapshots": [s.to_dict() for s in snapshots]
    }

@router.post("/simulate")
def run_simulation(req: SimulationRequest) -> Dict[str, Any]:
    sim = get_simulator()
    incident_zone = sim.get_zone(req.incident_zone_id)
    if not incident_zone:
        raise HTTPException(status_code=404, detail=f"Incident zone '{req.incident_zone_id}' not found.")

    # 1. Search candidates
    candidates = CandidateZoneSearch.find_surrounding_candidates(
        req.incident_zone_id,
        sim.zones_data,
        max_radius_km=req.candidate_radius_km
    )

    if not candidates:
        raise HTTPException(status_code=400, detail="No candidate zones found within search radius.")

    # 2. Simulate candidates
    scenario = get_scenario(req.scenario_key)
    candidates_snapshots = {}
    for c in candidates:
        zid = c["zone_id"]
        candidates_snapshots[zid] = sim.simulate_zone(zid, req.scenario_key, req.horizon_hours)

    # 3. Rank candidate risk emergence
    rankings = ZoneRanker.rank_candidates(candidates, candidates_snapshots)
    next_prone = rankings[0]  # Top ranked

    # 4. Generate audit trail
    record = PredictionAuditTrail.generate_prediction_record(
        incident_zone,
        next_prone,
        rankings,
        req.scenario_key,
        req.horizon_hours
    )

    # Store in prediction history memory
    PREDICTION_HISTORY[record["prediction_id"]] = record

    # 5. Generate GeoJSON output
    geojson = GeoJSONExporter.generate_geojson(
        incident_zone,
        next_prone.zone_id,
        [r.to_dict() for r in rankings]
    )

    return {
        "prediction_record": record,
        "geojson": geojson
    }

@router.get("/prediction/{prediction_id}")
def get_prediction(prediction_id: str) -> Dict[str, Any]:
    record = PREDICTION_HISTORY.get(prediction_id)
    if not record:
        raise HTTPException(status_code=404, detail=f"Prediction ID '{prediction_id}' not found in audit history.")
    return record

@router.get("/history/{zone_id}")
def get_zone_history(zone_id: str) -> Dict[str, Any]:
    sim = get_simulator()
    zone_data = sim.get_zone(zone_id)
    if not zone_data:
        raise HTTPException(status_code=404, detail=f"Zone '{zone_id}' not found.")

    matching_predictions = [
        rec for rec in PREDICTION_HISTORY.values()
        if rec["source_incident"]["zone_id"] == zone_id or rec["next_emergent_risk"]["zone_id"] == zone_id
    ]

    return {
        "zone_id": zone_id,
        "location_name": zone_data.get("location_name", "Dibang Valley Zone"),
        "historical_prediction_runs": len(matching_predictions),
        "records": matching_predictions
    }
