from fastapi import APIRouter

from app.api.v1.endpoints import alerts, auth, reports, risk, roads

api_router = APIRouter()

api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(risk.router, prefix="/risk", tags=["risk"])
api_router.include_router(reports.router, prefix="/reports", tags=["reports"])
api_router.include_router(alerts.router, prefix="/alerts", tags=["alerts"])
api_router.include_router(roads.router, prefix="/roads", tags=["roads"])
