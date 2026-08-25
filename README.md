# NER Landslide Early Warning System

SIH 2026 — Problem Statement 26001 (Ministry of Development of North Eastern Region).
AI-based early warning and landslide risk monitoring for India's North Eastern Region.

## Structure

```
app/        Flutter client (citizen / field official / analyst-admin)
backend/    FastAPI service (risk API, reports API, alert triggers)
ml/         Risk model training + GIS/rainfall feature pipelines
functions/  Firebase Cloud Functions (role claims, auto-alerts, SMS fan-out)
firebase/   Firestore + Storage security rules
```

Roles are stored on the Firestore `users/{uid}` doc and mirrored to a Firebase
Auth custom claim (`role`) by the `onUserCreateSetRole` Cloud Function, so
both the Flutter router and the FastAPI backend can gate access consistently.

## Getting started

### 1. Firebase project
1. Create a Firebase project, enable Auth (Email/Password), Firestore, Storage,
   Cloud Messaging.
2. `npm install -g firebase-tools && firebase login`
3. Replace the placeholder project id in `.firebaserc`.
4. From `app/`, run `flutterfire configure` to generate real
   `lib/firebase_options.dart` values (the checked-in one is a placeholder
   that throws until this is run).
5. Download a service account key for the backend and save it as
   `backend/firebase-service-account.json` (gitignored).
6. Deploy rules/functions: `firebase deploy --only firestore:rules,storage:rules,functions`.

### 2. Backend (FastAPI)
```
cd backend
python -m venv .venv && .venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env   # fill in Firebase + SMS provider credentials
uvicorn app.main:app --reload
```

### 3. ML
```
cd ml
python -m venv .venv && .venv\Scripts\activate
pip install -r requirements.txt
python -m src.models.train   # trains on a synthetic placeholder dataset for now
```

### 4. Flutter app
```
cd app
flutter pub get
flutter run
```

## Status

This is an initial scaffold: navigation, routing, role gating, and API/service
interfaces are wired up, but most data operations are stubbed with `TODO`s
(search for `TODO` across the repo). See each module's README/comments for
what's next.

## SMS alerts

SMS is a hard requirement (not a fallback) per the problem statement, since
parts of NER have poor data connectivity. Configure `SMS_PROVIDER` in
`backend/.env` to `twilio` or `msg91`; see `backend/app/services/sms_service.py`
and `functions/src/alerts/sendSmsAlert.ts`.
