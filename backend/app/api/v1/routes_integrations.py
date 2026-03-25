"""Google Workspace integration routes.

/integrations/google/connect   – initiate OAuth consent (returns URL)
/integrations/google/callback  – OAuth redirect handler (saves tokens)
/integrations/google/status    – check if current user has connected
/integrations/google/disconnect – revoke & remove tokens

/google/gmail/*                – real Gmail API
/google/calendar/*             – real Calendar API
/google/drive/*                – real Drive API
/google/tasks/*                – real Tasks API
/maps/*                        – local haversine helpers (unchanged)
"""

from __future__ import annotations

import logging
import secrets
from datetime import date, datetime, timedelta, timezone
from urllib.parse import urlencode

import httpx
from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import RedirectResponse
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, require_roles
from app.core.config import settings
from app.db.session import get_db
from app.models.core import BaseLocation, ReserveUnit, User, UserRole
from app.services.google_service import GoogleService, encrypt_token

router = APIRouter()
svc = GoogleService()
log = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Temporary in-memory state store for CSRF.  Replace with Redis / DB
# for multi-instance deployments.
# ---------------------------------------------------------------------------
_oauth_states: dict[str, str] = {}  # state_nonce → user_id


# ── OAuth connect / disconnect flow ───────────────────────────────────────────

@router.get(
    "/integrations/google/connect",
    dependencies=[Depends(require_roles("admin", "manager", "agent"))],
)
def google_connect(user: User = Depends(get_current_user)):
    """Return a Google OAuth consent URL for the current user."""
    if not settings.google_client_id or not settings.google_client_secret:
        raise HTTPException(
            status_code=500,
            detail="Google OAuth is not configured. Set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET.",
        )
    redirect_uri = settings.google_redirect_uri.replace(
        "/auth/google/callback", "/integrations/google/callback"
    )
    state = secrets.token_urlsafe(32)
    _oauth_states[state] = user.id

    query = urlencode(
        {
            "client_id": settings.google_client_id,
            "redirect_uri": redirect_uri,
            "response_type": "code",
            "scope": settings.google_workspace_scopes,
            "access_type": "offline",
            "prompt": "consent",
            "state": state,
        }
    )
    url = f"https://accounts.google.com/o/oauth2/v2/auth?{query}"
    return {"url": url, "state": state}


@router.get("/integrations/google/callback")
async def google_connect_callback(
    code: str | None = None,
    state: str | None = None,
    error: str | None = None,
    db: Session = Depends(get_db),
):
    """Handle OAuth redirect from Google; persist refresh token on the user."""
    if error:
        log.warning("Google OAuth error: %s", error)
        return RedirectResponse(url=f"{settings.allowed_origins.split(',')[0]}/settings?google=error")

    if not code or not state:
        raise HTTPException(status_code=400, detail="Missing code or state")

    user_id = _oauth_states.pop(state, None)
    if not user_id:
        raise HTTPException(status_code=400, detail="Invalid or expired OAuth state")

    redirect_uri = settings.google_redirect_uri.replace(
        "/auth/google/callback", "/integrations/google/callback"
    )

    async with httpx.AsyncClient(timeout=20.0) as client:
        resp = await client.post(
            "https://oauth2.googleapis.com/token",
            data={
                "code": code,
                "client_id": settings.google_client_id,
                "client_secret": settings.google_client_secret,
                "redirect_uri": redirect_uri,
                "grant_type": "authorization_code",
            },
        )
    if resp.status_code >= 400:
        log.error("Token exchange failed: %s", resp.text)
        return RedirectResponse(url=f"{settings.allowed_origins.split(',')[0]}/settings?google=error")

    token_data = resp.json()
    refresh_token = token_data.get("refresh_token")
    if not refresh_token:
        log.error("No refresh_token returned (did you use prompt=consent?)")
        return RedirectResponse(url=f"{settings.allowed_origins.split(',')[0]}/settings?google=error")

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    user.google_refresh_token = encrypt_token(refresh_token)
    user.google_token_scopes = token_data.get("scope", settings.google_workspace_scopes)
    user.google_connected_at = datetime.now(timezone.utc)
    db.commit()

    frontend_origin = settings.allowed_origins.split(",")[0].strip()
    return RedirectResponse(url=f"{frontend_origin}/settings?google=connected")


@router.get(
    "/integrations/google/status",
    dependencies=[Depends(require_roles("admin", "manager", "agent"))],
)
def google_status(user: User = Depends(get_current_user)):
    connected = bool(user.google_refresh_token)
    return {
        "connected": connected,
        "scopes": user.google_token_scopes.split() if user.google_token_scopes else [],
        "connected_at": user.google_connected_at.isoformat() if user.google_connected_at else None,
    }


@router.post(
    "/integrations/google/disconnect",
    dependencies=[Depends(require_roles("admin", "manager", "agent"))],
)
def google_disconnect(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    user.google_refresh_token = None
    user.google_token_scopes = None
    user.google_connected_at = None
    db.commit()
    return {"disconnected": True}


# ── Helper to get token or 403 ────────────────────────────────────────────────

def _require_google_token(user: User) -> str:
    if not user.google_refresh_token:
        raise HTTPException(
            status_code=403,
            detail="Google Workspace is not connected. Visit Settings → Integrations to connect.",
        )
    return user.google_refresh_token


# ── Gmail endpoints ──────────────────────────────────────────────────────────

class GmailPayload(BaseModel):
    to_email: str
    subject: str
    body: str


@router.post("/google/gmail/send-follow-up")
def gmail_send(payload: GmailPayload, user: User = Depends(require_roles("admin", "manager", "agent"))):
    token = _require_google_token(user)
    return svc.send_gmail(
        refresh_token=token,
        to_email=payload.to_email,
        subject=payload.subject,
        body=payload.body,
        sender_email=user.email,
    )


# ── Calendar endpoints ───────────────────────────────────────────────────────

class CalendarEventPayload(BaseModel):
    summary: str
    start: datetime
    end: datetime | None = None
    description: str | None = None
    location: str | None = None


@router.post("/google/calendar/create-event")
def calendar_create(payload: CalendarEventPayload, user: User = Depends(require_roles("admin", "manager", "agent"))):
    token = _require_google_token(user)
    return svc.create_calendar_event(
        refresh_token=token,
        summary=payload.summary,
        start=payload.start,
        end=payload.end,
        description=payload.description,
        location=payload.location,
    )


@router.get("/google/calendar/events")
def calendar_list(
    days_ahead: int = Query(default=14, ge=1, le=90),
    user: User = Depends(require_roles("admin", "manager", "agent")),
):
    token = _require_google_token(user)
    now = datetime.now(timezone.utc)
    return svc.list_calendar_events(
        refresh_token=token,
        time_min=now,
        time_max=now + timedelta(days=days_ahead),
    )


@router.post("/google/calendar/sync-brief")
def calendar_sync_brief(
    brief_id: str,
    user: User = Depends(require_roles("admin", "manager", "agent")),
    db: Session = Depends(get_db),
):
    from app.models.core import Brief
    token = _require_google_token(user)
    brief = db.query(Brief).filter(Brief.id == brief_id).first()
    if not brief:
        raise HTTPException(status_code=404, detail="Brief not found")
    if not brief.brief_date:
        raise HTTPException(status_code=400, detail="Brief has no scheduled date")
    location_parts = [brief.alt_address_street, brief.alt_address_city, brief.alt_address_state]
    location = ", ".join(p for p in location_parts if p) or None
    return svc.sync_brief_to_calendar(
        refresh_token=token,
        brief_title=brief.brief_title or "Untitled Brief",
        brief_date=brief.brief_date,
        start_time=brief.start_time,
        location=location,
        notes=brief.notes,
    )


# ── Drive endpoints ──────────────────────────────────────────────────────────

@router.get("/google/drive/files")
def drive_list(
    max_results: int = Query(default=25, ge=1, le=100),
    user: User = Depends(require_roles("admin", "manager", "agent")),
):
    token = _require_google_token(user)
    return svc.list_drive_files(refresh_token=token, max_results=max_results)


@router.post("/google/drive/upload-material")
def drive_upload(file_name: str, user: User = Depends(require_roles("admin", "manager", "agent"))):
    """Placeholder: accepts file_name; real file upload requires multipart form."""
    token = _require_google_token(user)
    content = f"Agent Tracker export: {file_name}".encode()
    return svc.upload_to_drive(
        refresh_token=token,
        file_name=file_name,
        content=content,
        mime_type="text/plain",
    )


# ── Tasks endpoints ──────────────────────────────────────────────────────────

class TaskPayload(BaseModel):
    title: str
    notes: str | None = None
    due: datetime | None = None


@router.post("/google/tasks/create-follow-up")
def tasks_create(payload: TaskPayload, user: User = Depends(require_roles("admin", "manager", "agent"))):
    token = _require_google_token(user)
    return svc.create_task(
        refresh_token=token,
        title=payload.title,
        notes=payload.notes,
        due=payload.due,
    )


@router.get("/google/tasks/list")
def tasks_list(
    max_results: int = Query(default=25, ge=1, le=100),
    show_completed: bool = Query(default=False),
    user: User = Depends(require_roles("admin", "manager", "agent")),
):
    token = _require_google_token(user)
    return svc.list_tasks(
        refresh_token=token,
        max_results=max_results,
        show_completed=show_completed,
    )


@router.get("/google/tasks/lists")
def task_lists(user: User = Depends(require_roles("admin", "manager", "agent"))):
    token = _require_google_token(user)
    return svc.list_task_lists(refresh_token=token)


# ── Workspace Directory sync ─────────────────────────────────────────────────

@router.get("/integrations/google/workspace-users")
def list_workspace_users(user: User = Depends(require_roles("admin"))):
    """Preview users from Google Workspace directory (admin only)."""
    token = _require_google_token(user)
    domain = settings.google_workspace_domain
    if not domain:
        raise HTTPException(
            status_code=400,
            detail="GOOGLE_WORKSPACE_DOMAIN is not configured.",
        )
    return svc.list_workspace_users(refresh_token=token, domain=domain)


class WorkspaceSyncOptions(BaseModel):
    default_role: str = "agent"
    dry_run: bool = True


@router.post("/integrations/google/sync-workspace-users")
def sync_workspace_users(
    opts: WorkspaceSyncOptions,
    user: User = Depends(require_roles("admin")),
    db: Session = Depends(get_db),
):
    """Sync users from Google Workspace directory into the app database.

    - Skips suspended Workspace accounts.
    - Creates new users that don't exist yet (matched by email).
    - Updates first/last name on existing users if they've changed.
    - Never downgrades roles or removes admin flags.
    """
    token = _require_google_token(user)
    domain = settings.google_workspace_domain
    if not domain:
        raise HTTPException(status_code=400, detail="GOOGLE_WORKSPACE_DOMAIN is not configured.")

    try:
        role = UserRole(opts.default_role)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Invalid role: {opts.default_role}")

    workspace_users = svc.list_workspace_users(refresh_token=token, domain=domain)

    created = []
    updated = []
    skipped = []

    for wu in workspace_users:
        if wu.get("suspended"):
            skipped.append({"email": wu["email"], "reason": "suspended"})
            continue

        existing = db.query(User).filter(User.email == wu["email"]).first()
        if existing:
            changed = False
            if wu["first_name"] and existing.first_name != wu["first_name"]:
                existing.first_name = wu["first_name"]
                changed = True
            if wu["last_name"] and existing.last_name != wu["last_name"]:
                existing.last_name = wu["last_name"]
                changed = True
            if changed:
                if not opts.dry_run:
                    db.commit()
                updated.append({"email": wu["email"], "first_name": wu["first_name"], "last_name": wu["last_name"]})
            else:
                skipped.append({"email": wu["email"], "reason": "no changes"})
        else:
            if not opts.dry_run:
                new_user = User(
                    email=wu["email"],
                    first_name=wu["first_name"] or "Workspace",
                    last_name=wu["last_name"] or "User",
                    role=role,
                    is_admin=False,
                )
                db.add(new_user)
            created.append({
                "email": wu["email"],
                "first_name": wu["first_name"],
                "last_name": wu["last_name"],
                "role": role.value,
            })

    if not opts.dry_run:
        db.commit()

    return {
        "dry_run": opts.dry_run,
        "domain": domain,
        "created": created,
        "updated": updated,
        "skipped": skipped,
        "summary": {
            "total_workspace_users": len(workspace_users),
            "created": len(created),
            "updated": len(updated),
            "skipped": len(skipped),
        },
    }


# ── Maps / distance helpers (local math, no Google API) ──────────────────────

@router.get("/maps/distances", dependencies=[Depends(require_roles("admin", "manager", "agent"))])
def map_distances(lat1: float, lon1: float, lat2: float, lon2: float):
    if not (-90 <= lat1 <= 90 and -90 <= lat2 <= 90 and -180 <= lon1 <= 180 and -180 <= lon2 <= 180):
        return {"error": "Invalid coordinate range"}
    return {"miles": round(svc.haversine_miles(lat1, lon1, lat2, lon2), 2)}


@router.get("/maps/bases", dependencies=[Depends(require_roles("admin", "manager", "agent"))])
def map_bases(region_id: str | None = None, db: Session = Depends(get_db)):
    q = db.query(BaseLocation)
    if region_id:
        q = q.filter(BaseLocation.region_id == region_id)
    return q.all()


@router.get("/maps/weekend-opportunities", dependencies=[Depends(require_roles("admin", "manager", "agent"))])
def weekend_opportunities(
    max_miles: float = Query(default=20),
    start_date: date | None = None,
    end_date: date | None = None,
    db: Session = Depends(get_db),
):
    if max_miles <= 0 or max_miles > 500:
        return {"error": "max_miles out of allowed range"}
    bases = db.query(BaseLocation).all()
    units = db.query(ReserveUnit).all()
    opportunities = []
    for i in range(len(bases)):
        for j in range(i + 1, len(bases)):
            b1 = bases[i]
            b2 = bases[j]
            if b1.latitude is None or b1.longitude is None or b2.latitude is None or b2.longitude is None:
                continue
            miles = svc.haversine_miles(b1.latitude, b1.longitude, b2.latitude, b2.longitude)
            if miles <= max_miles:
                opportunities.append({"base_a": b1.name, "base_b": b2.name, "miles": round(miles, 2)})
    return {"window_start": start_date, "window_end": end_date, "units_count": len(units), "opportunities": opportunities[:25]}


# ── Legacy calendar events from DB (non-Google) ─────────────────────────────

@router.get("/calendar/events", dependencies=[Depends(require_roles("admin", "manager", "agent"))])
def calendar_events(db: Session = Depends(get_db)):
    units = db.query(ReserveUnit).all()
    return [{"unit_id": u.id, "unit_name": u.name, "next_follow_up_date": u.next_follow_up_date} for u in units if u.next_follow_up_date]
