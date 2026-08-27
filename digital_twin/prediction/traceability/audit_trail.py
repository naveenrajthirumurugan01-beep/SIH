"""
Audit Trail & Traceability - Generates full step-by-step physical explanations and audit records.
Ensures every Digital Twin prediction is inspectable and explainable.
"""

import uuid
from datetime import datetime, timezone
from typing import Dict, Any, List
from digital_twin.prediction.ranking.zone_ranker import CandidateEvaluation

class PredictionAuditTrail:
    @staticmethod
    def generate_prediction_record(
        source_incident_zone: Dict[str, Any],
        selected_next_prone: CandidateEvaluation,
        all_candidate_evaluations: List[CandidateEvaluation],
        scenario_name: str,
        horizon_hours: float,
        model_version: str = "v1.0.0-physics-twin",
        calculation_version: str = "v1.0-mohr-coulomb"
    ) -> Dict[str, Any]:
        pred_id = f"pred_dt_{uuid.uuid4().hex[:10]}"
        now_iso = datetime.now(timezone.utc).isoformat()

        why_explanation = [
            f"1. Pore pressure increased from {selected_next_prone.pore_pressure_state['u_initial_kpa']} kPa to {selected_next_prone.pore_pressure_state['u_final_kpa']} kPa under infiltrating rainfall.",
            f"2. Effective stress reduced to {selected_next_prone.pore_pressure_state['effective_stress_final_kpa']} kPa, weakening Mohr-Coulomb shear strength.",
            f"3. Displacement trend transitioned to {selected_next_prone.displacement_trend} with acceleration {selected_next_prone.stability_state.get('displacement_acceleration', 0.8)} mm/h².",
            f"4. Slope geometry ({source_incident_zone.get('slope_angle', 48.0)}°) and high antecedence preconditioned terrain stability degradation.",
            f"5. Candidate exhibited highest emerging risk growth (+{round(selected_next_prone.risk_change, 2)}) across 5.0 km spatial search radius."
        ]

        physical_chain = [
            "Source Incident Identified",
            "Spatial Candidate Area Created",
            "Rainfall Infiltration & Pore-Fluid Coupling",
            "Pore Pressure Buildup & Effective Stress Reduction",
            "Shear Strength Degradation & Kinematic Acceleration",
            "Risk Evolution & Timestep Integration",
            "Emerging Risk Ranking",
            f"Selected Next Emergent Risk: {selected_next_prone.zone_id}"
        ]

        return {
            "prediction_id": pred_id,
            "timestamp": now_iso,
            "simulation_scenario": scenario_name,
            "prediction_horizon_hours": horizon_hours,
            "model_version": model_version,
            "calculation_version": calculation_version,
            "dataset_version": "dibang_valley_synthetic_v1.0",
            "simulation_status": "PROTOTYPE_SIMULATION",
            "validation_status": "NOT_YET_VALIDATED_WITH_LOCAL_FIELD_OBSERVATIONS",
            "source_incident": {
                "zone_id": source_incident_zone["zone_id"],
                "location_name": source_incident_zone.get("location_name", "Incident Slope"),
                "current_risk": source_incident_zone.get("current_risk_score", 0.82),
                "current_level": source_incident_zone.get("current_risk_level", "CRITICAL")
            },
            "next_emergent_risk": selected_next_prone.to_dict(),
            "why_selected": why_explanation,
            "physical_causality_chain": physical_chain,
            "candidate_rankings": [c.to_dict() for c in all_candidate_evaluations]
        }
