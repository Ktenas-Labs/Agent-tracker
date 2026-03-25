import uuid
import secrets
from urllib.parse import urlencode
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session
import httpx

from app.core.security import create_access_token
from app.core.config import settings
from app.db.session import get_db
from app.models.core import User, UserRole
from app.api.deps import get_current_user

router = APIRouter()


def _split_display_name(name: str | None) -> tuple[str, str]:
    if not name or not name.strip():
        return "Google", "User"
    parts = name.strip().split(None, 1)
    if len(parts) == 1:
        return parts[0], "User"
    return parts[0], parts[1]


def _user_payload(user: User) -> dict:
    return {
        "id": user.id,
        "email": user.email,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "role": user.role.value,
        "is_admin": user.is_admin,
    }


class FirebaseTokenRequest(BaseModel):
    id_token: str


class MockLoginRequest(BaseModel):
    email: str
    first_name: str = "Demo"
    last_name: str = "User"
    role: str = "agent"
    is_admin: bool = False


@router.post("/auth/firebase")
def auth_firebase(payload: FirebaseTokenRequest, db: Session = Depends(get_db)):
    """Exchange a Firebase / Identity Platform ID token for an app JWT."""
    if not settings.firebase_auth_enabled:
        raise HTTPException(status_code=404, detail="Firebase auth is not enabled")
    from app.services.firebase_auth import verify_firebase_id_token

    try:
        claims = verify_firebase_id_token(payload.id_token)
    except Exception as ex:
        raise HTTPException(status_code=401, detail="Invalid Firebase ID token") from ex
    email = claims.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="Token is missing email claim")
    first, last = _split_display_name(claims.get("name"))
    user = db.query(User).filter(User.email == email).first()
    if not user:
        if settings.restrict_login_to_known_users:
            raise HTTPException(
                status_code=403,
                detail=(
                    f"No account found for {email}. "
                    "Ask your administrator to add you, or sync users from Google Workspace."
                ),
            )
        user = User(
            id=str(uuid.uuid4()),
            email=email,
            first_name=first,
            last_name=last,
            role=UserRole.agent,
            is_admin=False,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
    access_token = create_access_token(subject=user.id, role=user.role.value)
    return {
        "token_type": "bearer",
        "access_token": access_token,
        "user": _user_payload(user),
        "firebase_uid": claims.get("uid") or claims.get("sub"),
    }


@router.get("/auth/google/login")
def google_login_url():
    if not settings.google_client_id or not settings.google_redirect_uri:
        return {"configured": False, "note": "Set GOOGLE_CLIENT_ID and GOOGLE_REDIRECT_URI in env"}
    state = secrets.token_urlsafe(24)
    scope = settings.google_workspace_scopes
    query = urlencode(
        {
            "client_id": settings.google_client_id,
            "redirect_uri": settings.google_redirect_uri,
            "response_type": "code",
            "scope": scope,
            "access_type": "offline",
            "prompt": "consent",
            "state": state,
        }
    )
    url = f"https://accounts.google.com/o/oauth2/v2/auth?{query}"
    return {"configured": True, "url": url, "state": state}


@router.get("/auth/google/callback")
async def google_callback(code: str | None = None, state: str | None = None, db: Session = Depends(get_db)):
    if not code:
        raise HTTPException(status_code=400, detail="Missing authorization code")
    if not state:
        raise HTTPException(status_code=400, detail="Missing OAuth state")
    if not settings.google_client_id or not settings.google_client_secret or not settings.google_redirect_uri:
        raise HTTPException(status_code=500, detail="Google OAuth env vars are not configured")
    async with httpx.AsyncClient(timeout=20.0) as client:
        resp = await client.post(
            "https://oauth2.googleapis.com/token",
            data={
                "code": code,
                "client_id": settings.google_client_id,
                "client_secret": settings.google_client_secret,
                "redirect_uri": settings.google_redirect_uri,
                "grant_type": "authorization_code",
            },
        )
    if resp.status_code >= 400:
        raise HTTPException(status_code=400, detail="Google token exchange failed")
    token_payload = resp.json()
    id_token = token_payload.get("id_token")
    if not id_token:
        raise HTTPException(status_code=400, detail="Missing id_token from Google")
    async with httpx.AsyncClient(timeout=20.0) as client:
        userinfo_resp = await client.get(
            "https://openidconnect.googleapis.com/v1/userinfo",
            headers={"Authorization": f"Bearer {token_payload.get('access_token', '')}"},
        )
    if userinfo_resp.status_code >= 400:
        raise HTTPException(status_code=400, detail="Failed to fetch Google user info")
    userinfo = userinfo_resp.json()
    email = userinfo.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="Google account missing email")
    user = db.query(User).filter(User.email == email).first()
    if not user:
        if settings.restrict_login_to_known_users:
            raise HTTPException(
                status_code=403,
                detail=f"No account found for {email}. Ask your administrator to add you.",
            )
        first_name = userinfo.get("given_name") or "Google"
        last_name = userinfo.get("family_name") or "User"
        user = User(
            id=str(uuid.uuid4()),
            email=email,
            first_name=first_name,
            last_name=last_name,
            role=UserRole.agent,
            is_admin=False,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
    access_token = create_access_token(subject=user.id, role=user.role.value)
    return {
        "oauth": "ok",
        "access_token": access_token,
        "user": _user_payload(user),
    }


@router.post("/auth/mock-login")
def mock_login(payload: MockLoginRequest, db: Session = Depends(get_db)):
    if not settings.allow_mock_auth:
        raise HTTPException(status_code=404, detail="Not found")
    user = db.query(User).filter(User.email == payload.email).first()
    if not user:
        try:
            role = UserRole(payload.role)
        except Exception as ex:
            raise HTTPException(status_code=400, detail="Invalid role") from ex
        user = User(
            id=str(uuid.uuid4()),
            email=payload.email,
            first_name=payload.first_name,
            last_name=payload.last_name,
            role=role,
            is_admin=payload.is_admin,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
    token = create_access_token(subject=user.id, role=user.role.value)
    return {"access_token": token, "token_type": "bearer", "user": _user_payload(user)}


@router.get("/auth/me")
def me(user: User = Depends(get_current_user)):
    return _user_payload(user)
