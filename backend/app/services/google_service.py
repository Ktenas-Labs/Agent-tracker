"""Google Workspace integration service.

Wraps the google-api-python-client for Gmail, Calendar, Drive, and Tasks.
Each method accepts a *refresh_token* belonging to the calling user; the service
builds short-lived credentials from it using the app's OAuth client_id/secret.
"""

from __future__ import annotations

import base64
import logging
from datetime import datetime, date, time, timedelta, timezone
from email.mime.text import MIMEText
from math import radians, sin, cos, asin, sqrt
from typing import Any

from cryptography.fernet import Fernet, InvalidToken
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build

from app.core.config import settings

log = logging.getLogger(__name__)

SCOPES = settings.google_workspace_scopes.split()

# ---------------------------------------------------------------------------
# Token encryption helpers
# ---------------------------------------------------------------------------

def _fernet() -> Fernet | None:
    key = settings.google_token_encryption_key
    if not key:
        return None
    return Fernet(key.encode())


def encrypt_token(plaintext: str) -> str:
    f = _fernet()
    if f is None:
        return plaintext
    return f.encrypt(plaintext.encode()).decode()


def decrypt_token(ciphertext: str) -> str:
    f = _fernet()
    if f is None:
        return ciphertext
    try:
        return f.decrypt(ciphertext.encode()).decode()
    except InvalidToken:
        return ciphertext


# ---------------------------------------------------------------------------
# Credential builder
# ---------------------------------------------------------------------------

def _build_credentials(refresh_token_encrypted: str) -> Credentials:
    refresh_token = decrypt_token(refresh_token_encrypted)
    creds = Credentials(
        token=None,
        refresh_token=refresh_token,
        token_uri="https://oauth2.googleapis.com/token",
        client_id=settings.google_client_id,
        client_secret=settings.google_client_secret,
        scopes=SCOPES,
    )
    creds.refresh(Request())
    return creds


# ---------------------------------------------------------------------------
# Service class
# ---------------------------------------------------------------------------

class GoogleService:
    """Thin wrapper around Google Workspace REST APIs."""

    # -- Gmail ---------------------------------------------------------------

    def send_gmail(
        self,
        refresh_token: str,
        to_email: str,
        subject: str,
        body: str,
        sender_email: str | None = None,
    ) -> dict[str, Any]:
        creds = _build_credentials(refresh_token)
        service = build("gmail", "v1", credentials=creds, cache_discovery=False)

        msg = MIMEText(body)
        msg["To"] = to_email
        msg["Subject"] = subject
        if sender_email:
            msg["From"] = sender_email

        raw = base64.urlsafe_b64encode(msg.as_bytes()).decode()
        sent = service.users().messages().send(
            userId="me", body={"raw": raw}
        ).execute()

        return {
            "provider": "gmail",
            "message_id": sent.get("id"),
            "thread_id": sent.get("threadId"),
            "to": to_email,
            "subject": subject,
            "status": "sent",
        }

    # -- Calendar ------------------------------------------------------------

    def create_calendar_event(
        self,
        refresh_token: str,
        summary: str,
        start: datetime,
        end: datetime | None = None,
        description: str | None = None,
        location: str | None = None,
    ) -> dict[str, Any]:
        creds = _build_credentials(refresh_token)
        service = build("calendar", "v3", credentials=creds, cache_discovery=False)

        if end is None:
            end = start + timedelta(hours=1)

        event_body: dict[str, Any] = {
            "summary": summary,
            "start": {"dateTime": start.isoformat(), "timeZone": "America/New_York"},
            "end": {"dateTime": end.isoformat(), "timeZone": "America/New_York"},
        }
        if description:
            event_body["description"] = description
        if location:
            event_body["location"] = location

        event = service.events().insert(calendarId="primary", body=event_body).execute()

        return {
            "provider": "calendar",
            "event_id": event.get("id"),
            "html_link": event.get("htmlLink"),
            "summary": summary,
            "status": "created",
        }

    def list_calendar_events(
        self,
        refresh_token: str,
        time_min: datetime | None = None,
        time_max: datetime | None = None,
        max_results: int = 25,
    ) -> list[dict[str, Any]]:
        creds = _build_credentials(refresh_token)
        service = build("calendar", "v3", credentials=creds, cache_discovery=False)

        now = datetime.now(timezone.utc)
        params: dict[str, Any] = {
            "calendarId": "primary",
            "timeMin": (time_min or now).isoformat(),
            "maxResults": max_results,
            "singleEvents": True,
            "orderBy": "startTime",
        }
        if time_max:
            params["timeMax"] = time_max.isoformat()

        result = service.events().list(**params).execute()
        items = result.get("items", [])

        return [
            {
                "id": ev.get("id"),
                "summary": ev.get("summary"),
                "start": ev.get("start", {}).get("dateTime") or ev.get("start", {}).get("date"),
                "end": ev.get("end", {}).get("dateTime") or ev.get("end", {}).get("date"),
                "html_link": ev.get("htmlLink"),
            }
            for ev in items
        ]

    def sync_brief_to_calendar(
        self,
        refresh_token: str,
        brief_title: str,
        brief_date: date,
        start_time: time | None = None,
        location: str | None = None,
        notes: str | None = None,
    ) -> dict[str, Any]:
        dt_start = datetime.combine(
            brief_date,
            start_time or time(9, 0),
            tzinfo=timezone(timedelta(hours=-5)),
        )
        return self.create_calendar_event(
            refresh_token=refresh_token,
            summary=f"Brief: {brief_title}",
            start=dt_start,
            description=notes,
            location=location,
        )

    # -- Drive ---------------------------------------------------------------

    def upload_to_drive(
        self,
        refresh_token: str,
        file_name: str,
        content: bytes,
        mime_type: str = "application/pdf",
        folder_id: str | None = None,
    ) -> dict[str, Any]:
        from googleapiclient.http import MediaInMemoryUpload

        creds = _build_credentials(refresh_token)
        service = build("drive", "v3", credentials=creds, cache_discovery=False)

        metadata: dict[str, Any] = {"name": file_name}
        if folder_id:
            metadata["parents"] = [folder_id]

        media = MediaInMemoryUpload(content, mimetype=mime_type, resumable=False)
        created = service.files().create(
            body=metadata, media_body=media, fields="id,name,webViewLink"
        ).execute()

        return {
            "provider": "drive",
            "file_id": created.get("id"),
            "file_name": created.get("name"),
            "web_link": created.get("webViewLink"),
            "status": "uploaded",
        }

    def list_drive_files(
        self,
        refresh_token: str,
        max_results: int = 25,
        query: str | None = None,
    ) -> list[dict[str, Any]]:
        creds = _build_credentials(refresh_token)
        service = build("drive", "v3", credentials=creds, cache_discovery=False)

        params: dict[str, Any] = {
            "pageSize": max_results,
            "fields": "files(id,name,mimeType,webViewLink,modifiedTime)",
            "orderBy": "modifiedTime desc",
        }
        if query:
            params["q"] = query

        result = service.files().list(**params).execute()
        return [
            {
                "id": f.get("id"),
                "name": f.get("name"),
                "mime_type": f.get("mimeType"),
                "web_link": f.get("webViewLink"),
                "modified": f.get("modifiedTime"),
            }
            for f in result.get("files", [])
        ]

    # -- Tasks ---------------------------------------------------------------

    def create_task(
        self,
        refresh_token: str,
        title: str,
        notes: str | None = None,
        due: datetime | None = None,
        task_list: str = "@default",
    ) -> dict[str, Any]:
        creds = _build_credentials(refresh_token)
        service = build("tasks", "v1", credentials=creds, cache_discovery=False)

        body: dict[str, Any] = {"title": title}
        if notes:
            body["notes"] = notes
        if due:
            body["due"] = due.isoformat() + "Z" if due.tzinfo is None else due.isoformat()

        task = service.tasks().insert(tasklist=task_list, body=body).execute()
        return {
            "provider": "tasks",
            "task_id": task.get("id"),
            "title": task.get("title"),
            "status": task.get("status"),
            "self_link": task.get("selfLink"),
        }

    def list_tasks(
        self,
        refresh_token: str,
        task_list: str = "@default",
        max_results: int = 25,
        show_completed: bool = False,
    ) -> list[dict[str, Any]]:
        creds = _build_credentials(refresh_token)
        service = build("tasks", "v1", credentials=creds, cache_discovery=False)

        result = service.tasks().list(
            tasklist=task_list,
            maxResults=max_results,
            showCompleted=show_completed,
        ).execute()
        return [
            {
                "id": t.get("id"),
                "title": t.get("title"),
                "notes": t.get("notes"),
                "due": t.get("due"),
                "status": t.get("status"),
            }
            for t in result.get("items", [])
        ]

    def list_task_lists(self, refresh_token: str) -> list[dict[str, Any]]:
        creds = _build_credentials(refresh_token)
        service = build("tasks", "v1", credentials=creds, cache_discovery=False)

        result = service.tasklists().list().execute()
        return [
            {"id": tl.get("id"), "title": tl.get("title")}
            for tl in result.get("items", [])
        ]

    # -- Admin Directory (Workspace user sync) --------------------------------

    def list_workspace_users(
        self,
        refresh_token: str,
        domain: str,
        max_results: int = 500,
    ) -> list[dict[str, Any]]:
        """List users from a Google Workspace domain via Admin Directory API.

        Requires the calling user to be a Workspace admin and the
        admin.directory.user.readonly scope to be granted.
        """
        creds = _build_credentials(refresh_token)
        service = build("admin", "directory_v1", credentials=creds, cache_discovery=False)

        users: list[dict[str, Any]] = []
        page_token: str | None = None

        while True:
            params: dict[str, Any] = {
                "domain": domain,
                "maxResults": min(max_results - len(users), 500),
                "orderBy": "email",
                "projection": "basic",
            }
            if page_token:
                params["pageToken"] = page_token

            result = service.users().list(**params).execute()

            for u in result.get("users", []):
                name = u.get("name", {})
                users.append({
                    "email": u.get("primaryEmail"),
                    "first_name": name.get("givenName", ""),
                    "last_name": name.get("familyName", ""),
                    "suspended": u.get("suspended", False),
                    "is_admin": u.get("isAdmin", False),
                    "org_unit": u.get("orgUnitPath", "/"),
                })

            page_token = result.get("nextPageToken")
            if not page_token or len(users) >= max_results:
                break

        return users

    # -- Haversine (local, no API) -------------------------------------------

    def haversine_miles(self, lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        r = 3958.8
        d_lat = radians(lat2 - lat1)
        d_lon = radians(lon2 - lon1)
        a = sin(d_lat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(d_lon / 2) ** 2
        return 2 * r * asin(sqrt(a))
