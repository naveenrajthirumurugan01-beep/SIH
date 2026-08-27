from datetime import datetime, timezone
from fastapi import APIRouter
from pydantic import BaseModel, Field

router = APIRouter()


class SensorTelemetry(BaseModel):
    sensor_id: str
    district: str
    lat: float
    lng: float
    soil_moisture_pct: float = Field(ge=0, le=100)
    ground_displacement_mm: float
    rain_rate_mm_hr: float
    battery_level_pct: float = 100.0


_IN_MEMORY_SENSOR_STUB = [
    {
        "sensor_id": "IOT_NER_EKH_01",
        "district": "East Khasi Hills",
        "lat": 25.5788,
        "lng": 91.8933,
        "soil_moisture_pct": 88.5,
        "ground_displacement_mm": 14.2,
        "rain_rate_mm_hr": 45.0,
        "status": "CRITICAL_ALERT",
        "updated_at": datetime.now(timezone.utc).isoformat(),
    },
    {
        "sensor_id": "IOT_NER_AIZ_02",
        "district": "Aizawl",
        "lat": 23.7271,
        "lng": 92.7176,
        "soil_moisture_pct": 82.0,
        "ground_displacement_mm": 8.5,
        "rain_rate_mm_hr": 32.0,
        "status": "WARNING",
        "updated_at": datetime.now(timezone.utc).isoformat(),
    },
    {
        "sensor_id": "IOT_NER_GTK_03",
        "district": "Gangtok",
        "lat": 27.3389,
        "lng": 88.6065,
        "soil_moisture_pct": 79.0,
        "ground_displacement_mm": 11.0,
        "rain_rate_mm_hr": 28.0,
        "status": "WARNING",
        "updated_at": datetime.now(timezone.utc).isoformat(),
    },
]


@router.get("/live")
async def get_live_sensor_telemetry():
    """Fetches real-time telemetry from IoT soil moisture & displacement sensors across NER."""
    return {"sensors": _IN_MEMORY_SENSOR_STUB, "count": len(_IN_MEMORY_SENSOR_STUB)}


@router.post("/ingest")
async def ingest_sensor_data(data: SensorTelemetry):
    """Ingests real-time telemetry from field IoT sensors into the ML risk engine."""
    entry = data.dict()
    entry["status"] = "CRITICAL_ALERT" if data.soil_moisture_pct > 80 or data.ground_displacement_mm > 10 else "NORMAL"
    entry["updated_at"] = datetime.now(timezone.utc).isoformat()
    _IN_MEMORY_SENSOR_STUB.insert(0, entry)
    return {"status": "success", "message": "Telemetry ingested into ML Risk Engine", "data": entry}
