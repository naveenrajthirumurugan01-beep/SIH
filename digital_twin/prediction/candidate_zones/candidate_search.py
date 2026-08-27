"""
Candidate Search - Spatial search area creation around active incident zone.
Excludes active incident zone and filters by search radius.
"""

from typing import List, Dict, Any
from digital_twin.models.spatial_prediction.spatial_prediction_model import haversine_distance_km

class CandidateZoneSearch:
    @staticmethod
    def find_surrounding_candidates(
        incident_zone_id: str,
        all_zones: List[Dict[str, Any]],
        max_radius_km: float = 10.0
    ) -> List[Dict[str, Any]]:
        """
        Finds surrounding candidate zones within max_radius_km, excluding incident_zone_id.
        """
        incident_zone = next((z for z in all_zones if z["zone_id"] == incident_zone_id), None)
        if not incident_zone:
            raise ValueError(f"Incident Zone '{incident_zone_id}' not found.")

        i_lat = incident_zone["latitude"]
        i_lon = incident_zone["longitude"]

        candidates = []
        for z in all_zones:
            if z["zone_id"] == incident_zone_id:
                continue

            dist = haversine_distance_km(i_lat, i_lon, z["latitude"], z["longitude"])
            if dist <= max_radius_km:
                z_copy = dict(z)
                z_copy["distance_from_current_incident"] = dist
                candidates.append(z_copy)

        # Sort candidates by distance initially for search efficiency
        candidates.sort(key=lambda x: x["distance_from_current_incident"])
        return candidates
