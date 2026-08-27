"""
API Schemas for Digital Twin Engine
"""

from pydantic import BaseModel, Field
from typing import List, Dict, Any, Optional

class SimulationRequest(BaseModel):
    incident_zone_id: str = Field("DV-007", description="Current critical/incident zone ID")
    scenario_key: str = Field("BASELINE", description="Simulation scenario key (BASELINE, RAINFALL_PLUS_50, etc.)")
    horizon_hours: float = Field(6.0, description="Simulation forecast horizon in hours (1.0 to 24.0)")
    candidate_radius_km: float = Field(10.0, description="Spatial search radius for candidate zones in km")

class ZoneStateResponse(BaseModel):
    zone_id: str
    location_name: str
    latitude: float
    longitude: float
    current_risk_score: float
    current_risk_level: str
    current_landslide_flag: bool
    timestamp: str

class ScenarioDetailResponse(BaseModel):
    scenario_key: str
    name: str
    description: str
    rainfall_multiplier: float
