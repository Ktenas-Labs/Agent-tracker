from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.schemas.operations import (
    ContactIn, ContactOut,
    ConversationIn, ConversationOut,
    BriefIn, BriefOut,
    TripIn, TripOut, TripBriefAssign,
    NearbyUnitOut,
)
from app.services.operations_service import OperationsService
from app.services.authorization import assert_unit_write_access, assert_agent_is_self
from app.api.deps import require_roles, get_current_user
from app.models.core import User

router = APIRouter()


@router.get("/contacts", response_model=list[ContactOut], dependencies=[Depends(require_roles("agent"))])
def list_contacts(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    service = OperationsService(db)
    if user.is_admin or user.is_manager:
        return service.list_contacts()
    return service.list_contacts_for_user(user.id)


@router.post("/contacts", response_model=ContactOut, dependencies=[Depends(require_roles("agent"))])
def create_contact(
    payload: ContactIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    # Verify write access for each unit being linked
    for unit_id in payload.unit_ids:
        assert_unit_write_access(db, user, unit_id)
    return OperationsService(db).create_contact(payload.model_dump())


@router.get("/conversations", response_model=list[ConversationOut], dependencies=[Depends(require_roles("agent"))])
def list_conversations(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    service = OperationsService(db)
    if user.is_admin or user.is_manager:
        return service.list_conversations()
    return service.list_conversations_for_user(user.id)


@router.post("/conversations", response_model=ConversationOut, dependencies=[Depends(require_roles("agent"))])
def create_conversation(
    payload: ConversationIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    assert_unit_write_access(db, user, payload.unit_id)
    assert_agent_is_self(user, payload.agent_id)
    return OperationsService(db).create_conversation(payload.model_dump())


@router.get("/briefs", response_model=list[BriefOut], dependencies=[Depends(require_roles("agent"))])
def list_briefs(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    service = OperationsService(db)
    if user.is_admin or user.is_manager:
        return service.list_briefs()
    return service.list_briefs_for_user(user.id)


@router.post("/briefs", response_model=BriefOut, dependencies=[Depends(require_roles("agent"))])
def create_brief(
    payload: BriefIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    for unit_id in payload.unit_ids:
        assert_unit_write_access(db, user, unit_id)
    assert_agent_is_self(user, payload.assigned_agent_id)
    return OperationsService(db).create_brief(payload.model_dump())


@router.patch("/briefs/{brief_id}", response_model=BriefOut, dependencies=[Depends(require_roles("agent"))])
def update_brief(
    brief_id: str,
    payload: BriefIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    svc = OperationsService(db)
    brief = svc.get_brief(brief_id)
    if not brief:
        raise HTTPException(status_code=404, detail="Brief not found")
    assert_agent_is_self(user, brief.assigned_agent_id)
    result = svc.update_brief(brief_id, payload.model_dump(exclude_unset=True))
    if not result:
        raise HTTPException(status_code=404, detail="Brief not found")
    return result


# ── Trips ───────────────────────────────────────────────────────────────────────

@router.get("/trips", response_model=list[TripOut], dependencies=[Depends(require_roles("agent"))])
def list_trips(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    svc = OperationsService(db)
    if user.is_admin or user.is_manager:
        return svc.list_trips()
    return svc.list_trips_for_agent(user.id)


@router.post("/trips", response_model=TripOut, dependencies=[Depends(require_roles("agent"))])
def create_trip(
    payload: TripIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    assert_agent_is_self(user, payload.agent_id)
    return OperationsService(db).create_trip(payload.model_dump())


@router.get("/trips/{trip_id}", response_model=TripOut, dependencies=[Depends(require_roles("agent"))])
def get_trip(trip_id: str, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    svc = OperationsService(db)
    trip = svc.get_trip(trip_id)
    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")
    if not (user.is_admin or user.is_manager) and trip.agent_id != user.id:
        raise HTTPException(status_code=403, detail="Not your trip")
    return trip


@router.patch("/trips/{trip_id}", response_model=TripOut, dependencies=[Depends(require_roles("agent"))])
def update_trip(
    trip_id: str,
    payload: TripIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    svc = OperationsService(db)
    trip = svc.get_trip(trip_id)
    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")
    if not (user.is_admin or user.is_manager) and trip.agent_id != user.id:
        raise HTTPException(status_code=403, detail="Not your trip")
    result = svc.update_trip(trip_id, payload.model_dump(exclude_unset=True))
    if not result:
        raise HTTPException(status_code=404, detail="Trip not found")
    return result


@router.get("/trips/{trip_id}/briefs", response_model=list[BriefOut], dependencies=[Depends(require_roles("agent"))])
def list_trip_briefs(trip_id: str, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    svc = OperationsService(db)
    trip = svc.get_trip(trip_id)
    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")
    if not (user.is_admin or user.is_manager) and trip.agent_id != user.id:
        raise HTTPException(status_code=403, detail="Not your trip")
    return svc.list_briefs_for_trip(trip_id)


@router.post("/trips/{trip_id}/briefs", response_model=BriefOut, dependencies=[Depends(require_roles("agent"))])
def add_brief_to_trip(
    trip_id: str,
    body: TripBriefAssign,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    svc = OperationsService(db)
    trip = svc.get_trip(trip_id)
    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")
    if not (user.is_admin or user.is_manager) and trip.agent_id != user.id:
        raise HTTPException(status_code=403, detail="Not your trip")
    brief = svc.get_brief(body.brief_id)
    if not brief:
        raise HTTPException(status_code=404, detail="Brief not found")
    svc.add_brief_to_trip(trip_id, body.brief_id)
    return svc.get_brief(body.brief_id)


@router.delete("/trips/{trip_id}/briefs/{brief_id}", dependencies=[Depends(require_roles("agent"))])
def remove_brief_from_trip(
    trip_id: str,
    brief_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    svc = OperationsService(db)
    trip = svc.get_trip(trip_id)
    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")
    if not (user.is_admin or user.is_manager) and trip.agent_id != user.id:
        raise HTTPException(status_code=403, detail="Not your trip")
    removed = svc.remove_brief_from_trip(trip_id, brief_id)
    if not removed:
        raise HTTPException(status_code=404, detail="Brief not on this trip")
    return {"ok": True}


# ── Nearby-unit suggestions ─────────────────────────────────────────────────────

@router.get(
    "/suggestions/nearby-units",
    response_model=list[NearbyUnitOut],
    dependencies=[Depends(require_roles("agent"))],
)
def suggest_nearby_units(
    lat: float = Query(..., description="Center latitude"),
    lon: float = Query(..., description="Center longitude"),
    radius_miles: float = Query(150.0, ge=1, le=500),
    start_date: date | None = Query(None, description="Window start for brief collision check"),
    end_date: date | None = Query(None, description="Window end for brief collision check"),
    exclude_unit_ids: list[str] = Query(default=[], description="Unit IDs to omit (e.g. already on the trip)"),
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    """
    Return reserve units within radius_miles of (lat, lon), sorted by distance.
    Pass start_date + end_date to flag units that already have a brief scheduled
    in that window. Pass exclude_unit_ids to hide units already on your trip.
    """
    svc = OperationsService(db)
    results = svc.suggest_nearby_units(
        lat=lat,
        lon=lon,
        radius_miles=radius_miles,
        start_date=start_date,
        end_date=end_date,
        exclude_unit_ids=exclude_unit_ids,
    )
    return results
