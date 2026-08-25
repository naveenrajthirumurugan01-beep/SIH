# Architecture Overview

## Data flow

1. **Ingestion** (`ml/src/features/`): rainfall time series + DEM/terrain
   rasters for NER districts are pulled and turned into features.
2. **Training** (`ml/src/models/train.py`): XGBoost/LightGBM (sklearn
   fallback) trained on terrain + rainfall + historical incident features,
   saved to `ml/models/risk_model.joblib`.
3. **Serving** (`backend/app/services/risk_service.py`): the FastAPI backend
   loads the model and exposes `GET /api/v1/risk/heatmap` and
   `GET /api/v1/risk/district/{name}`.
4. **Persistence** (`districts_risk` Firestore collection): a periodic job
   (TODO — not yet scaffolded; candidate: a scheduled Cloud Function or a
   cron on the backend) writes fresh scores so the app can also read risk
   data directly from Firestore for offline-friendly caching.
5. **Alerting**: `functions/src/alerts/onRiskUpdate.ts` watches
   `districts_risk` for escalations into high/very_high and writes to
   `alerts/`; `functions/src/alerts/sendSmsAlert.ts` fans that out to SMS
   (Twilio/MSG91) and FCM push. Analysts can also manually trigger/override
   alerts via `POST /api/v1/alerts/trigger` on the backend, which should
   write to the same `alerts/` collection as the single source of truth.
6. **Reporting**: citizens and field officials submit geo-tagged
   photo/video reports (Flutter `features/reports/`) directly to Firestore
   `reports/`; field official reports carry a higher `trust_weight`.
   Analysts approve/reject via the moderation queue, and approved reports
   should eventually feed back into the risk model as a feature
   (`historical_incident_count` in `ml/src/models/train.py`).

## Role gating

Role lives on `users/{uid}.role` in Firestore and is mirrored to a Firebase
Auth custom claim by `functions/src/auth/onUserCreate.ts`. The Flutter
router (`app/lib/core/routing/app_router.dart`) reads the role from the
signed-in user's profile to pick a home screen; the backend
(`backend/app/core/security.py`) reads the same claim from the verified ID
token to gate endpoints.

## Why Firestore *and* a FastAPI backend

Firestore is used directly from Flutter for simple CRUD (reports, road
status) to keep the client responsive and get offline caching for free.
The FastAPI backend owns anything that needs server-side logic Firestore
security rules can't express cleanly: ML inference, trust-weighted
aggregation, and the SMS gateway integration.
