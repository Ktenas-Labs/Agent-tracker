"""Verify Firebase / Identity Platform ID tokens using the Firebase Admin SDK."""

from __future__ import annotations

import firebase_admin
from firebase_admin import auth as firebase_auth
from firebase_admin import credentials

from app.core.config import settings

_initialized = False


def _ensure_firebase_app() -> None:
    global _initialized
    if _initialized:
        return
    if firebase_admin._apps:
        _initialized = True
        return

    if settings.firebase_credentials_path:
        cred = credentials.Certificate(settings.firebase_credentials_path)
    else:
        cred = credentials.ApplicationDefault()

    # Pass project ID explicitly when set — required when ADC cannot auto-detect it
    # (e.g. local dev with `gcloud auth application-default login`).
    # On Cloud Run the service account project is detected automatically.
    options: dict = {}
    if settings.firebase_project_id:
        options["projectId"] = settings.firebase_project_id

    firebase_admin.initialize_app(cred, options)
    _initialized = True


def verify_firebase_id_token(id_token: str) -> dict:
    """Validate a Firebase ID token and return decoded claims (uid, email, name, etc.)."""
    _ensure_firebase_app()
    return firebase_auth.verify_id_token(id_token)
