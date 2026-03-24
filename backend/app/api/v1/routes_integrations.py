from datetime import date
from fastapi import APIRouter, Query, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models.core import BaseLocation, ReserveUnit
from app.services.google_service import GoogleService
from app.api.deps import require_roles

router = APIRouter()
svc = GoogleService()


class GmailPayload(BaseModel):
    to_email: str
    subject: str
    body: str


@router.post("/google/gmail/send-follow-up", dependencies=[Depends(require_roles("admin", "manager", "agent"))])
def gmail_send(payload: GmailPayload):
    return svc.send_gmail_followup(payload.to_email, payload.subject, payload.body)


@router.post("/google/drive/upload-material", dependencies=[Depends(require_roles("admin", "manager", "agent"))])
def drive_upload(file_name: str):
    return svc.upload_drive_material(file_name)


@router.post("/google/sheets/export", dependencies=[Depends(require_roles("admin", "manager"))])
def sheets_export(report_name: str):
    return svc.export_to_sheets(report_name)


@router.post("/google/docs/generate-brief-report", dependencies=[Depends(require_roles("admin", "manager", "agent"))])
def docs_generate(title: str):
    return svc.generate_doc(title)


@router.post("/google/tasks/create-follow-up", dependencies=[Depends(require_roles("admin", "manager", "agent"))])
def tasks_create(title: str):
    return svc.create_task(title)


@router.post("/google/contacts/sync", dependencies=[Depends(require_roles("admin", "manager"))])
def contacts_sync():
    return svc.sync_contacts()


@router.post("/google/calendar/sync", dependencies=[Depends(require_roles("admin", "manager", "agent"))])
def google_calendar_sync(brief_id: str):
    return svc.sync_calendar(brief_id)


@router.get("/maps/distances", dependencies=[Depends(require_roles("admin", "manager", "agent"))])
def map_distances(
    lat1: float,
    lon1: float,
    lat2: float,
    lon2: float,
):
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


@router.get("/calendar/events", dependencies=[Depends(require_roles("admin", "manager", "agent"))])
def calendar_events(db: Session = Depends(get_db)):
    units = db.query(ReserveUnit).all()
    return [{"unit_id": u.id, "unit_name": u.name, "next_follow_up_date": u.next_follow_up_date} for u in units if u.next_follow_up_date]
