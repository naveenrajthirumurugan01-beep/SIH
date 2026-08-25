import firebase_admin
from firebase_admin import auth, credentials, firestore, storage

from app.core.config import get_settings

_app: firebase_admin.App | None = None


def init_firebase() -> firebase_admin.App:
    """Initialize the Firebase Admin SDK once and reuse the app instance."""
    global _app
    if _app is not None:
        return _app

    settings = get_settings()
    cred = credentials.Certificate(settings.firebase_credentials_path)
    _app = firebase_admin.initialize_app(
        cred,
        {
            "projectId": settings.firebase_project_id,
            "storageBucket": f"{settings.firebase_project_id}.appspot.com",
        },
    )
    return _app


def get_firestore_client():
    init_firebase()
    return firestore.client()


def get_auth_client():
    init_firebase()
    return auth


def get_storage_bucket():
    init_firebase()
    return storage.bucket()
