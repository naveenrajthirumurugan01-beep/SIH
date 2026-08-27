"""
GeoJSON GIS Exporter - Generates GIS-compatible GeoJSON FeatureCollections for map visualization.
Tagging includes prediction_status: NEXT_EMERGENT_RISK, CURRENT_INCIDENT, EMERGING, HIGH, MODERATE, LOW.
"""

from typing import Dict, Any, List

class GeoJSONExporter:
    @staticmethod
    def generate_geojson(
        source_incident: Dict[str, Any],
        next_prone_id: str,
        candidates_evaluations: List[Dict[str, Any]]
    ) -> Dict[str, Any]:
        features = []

        # 1. Source Incident Feature
        inc_id = source_incident["zone_id"]
        features.append({
            "type": "Feature",
            "geometry": {
                "type": "Point",
                "coordinates": [source_incident["longitude"], source_incident["latitude"]]
            },
            "properties": {
                "zone_id": inc_id,
                "location_name": source_incident.get("location_name", "Incident Location"),
                "prediction_status": "CURRENT_INCIDENT",
                "risk_score": source_incident.get("current_risk_score", 0.82),
                "risk_level": source_incident.get("current_risk_level", "CRITICAL"),
                "distance_km": 0.0,
                "landslide_flag": True
            }
        })

        # 2. Candidate Features
        for c in candidates_evaluations:
            zid = c["zone_id"]
            if zid == next_prone_id:
                status = "NEXT_EMERGENT_RISK"
            elif c["predicted_risk"] >= 0.75:
                status = "CRITICAL"
            elif c["predicted_risk"] >= 0.50:
                status = "EMERGING"
            elif c["predicted_risk"] >= 0.25:
                status = "MODERATE"
            else:
                status = "LOW"

            features.append({
                "type": "Feature",
                "geometry": {
                    "type": "Point",
                    "coordinates": [c["longitude"], c["latitude"]]
                },
                "properties": {
                    "zone_id": zid,
                    "location_name": c["location_name"],
                    "prediction_status": status,
                    "current_risk": c["current_risk"],
                    "predicted_risk": c["predicted_risk"],
                    "risk_change": c["risk_change"],
                    "current_level": c["current_level"],
                    "predicted_level": c["predicted_level"],
                    "prediction_horizon": c["prediction_horizon"],
                    "distance_km": c["distance_from_current_incident"],
                    "dominant_factors": c["dominant_factors"]
                }
            })

        return {
            "type": "FeatureCollection",
            "crs": {
                "type": "name",
                "properties": {"name": "urn:ogc:def:crs:OGC:1.3:CRS84"}
            },
            "features": features
        }
