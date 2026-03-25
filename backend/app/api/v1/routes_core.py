from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.schemas.common import (
    RegionIn, RegionOut,
    BaseIn, BaseOut,
    UnitIn, UnitOut,
    UnitAssignmentIn, UnitAssignmentOut,
    UserOut,
    UserStateAssignmentIn, UserStateAssignmentOut,
)
from app.services.core_service import CoreService
from app.api.deps import require_roles, get_current_user
from app.models.core import User

router = APIRouter()


@router.get("/health")
def health():
    return {"status": "ok"}


# ── Regions ───────────────────────────────────────────────────────────────────

@router.get("/regions", response_model=list[RegionOut], dependencies=[Depends(require_roles("admin", "manager", "agent"))])
def list_regions(db: Session = Depends(get_db)):
    return CoreService(db).list_regions()


@router.post("/regions", response_model=RegionOut, dependencies=[Depends(require_roles("admin", "manager"))])
def create_region(payload: RegionIn, db: Session = Depends(get_db)):
    return CoreService(db).create_region(payload.model_dump())


# ── Bases ─────────────────────────────────────────────────────────────────────

@router.get("/bases", response_model=list[BaseOut], dependencies=[Depends(require_roles("admin", "manager", "agent"))])
def list_bases(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    service = CoreService(db)
    if user.role.value == "admin":
        return service.list_bases()
    return service.list_bases_for_user(user.id)


@router.post("/bases", response_model=BaseOut, dependencies=[Depends(require_roles("admin", "manager"))])
def create_base(payload: BaseIn, db: Session = Depends(get_db)):
    return CoreService(db).create_base(payload.model_dump())


# ── Units ─────────────────────────────────────────────────────────────────────

@router.get("/units", response_model=list[UnitOut], dependencies=[Depends(require_roles("admin", "manager", "agent"))])
def list_units(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    service = CoreService(db)
    if user.role.value == "admin":
        return service.list_units()
    return service.list_units_for_user(user.id)


@router.post("/units", response_model=UnitOut, dependencies=[Depends(require_roles("admin", "manager", "agent"))])
def create_unit(payload: UnitIn, db: Session = Depends(get_db)):
    try:
        return CoreService(db).create_unit(payload.model_dump())
    except Exception as ex:
        raise HTTPException(status_code=400, detail=str(ex)) from ex


@router.get("/units/my", response_model=list[UnitOut])
def list_my_units(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    service = CoreService(db)
    if user.role.value == "admin":
        return service.list_units()
    return service.list_units_for_user(user.id)


# ── Admin: regions / unit assignments ─────────────────────────────────────────

@router.post("/admin/regions", response_model=RegionOut, dependencies=[Depends(require_roles("admin", "manager"))])
def create_region_guarded(payload: RegionIn, db: Session = Depends(get_db)):
    return CoreService(db).create_region(payload.model_dump())


@router.post("/admin/unit-assignments", response_model=UnitAssignmentOut, dependencies=[Depends(require_roles("admin", "manager"))])
def assign_unit(payload: UnitAssignmentIn, db: Session = Depends(get_db)):
    return CoreService(db).assign_unit_to_user(payload.unit_id, payload.user_id)


# ── Admin: users ──────────────────────────────────────────────────────────────

@router.get("/admin/users", response_model=list[UserOut], dependencies=[Depends(require_roles("admin", "manager"))])
def list_users(db: Session = Depends(get_db)):
    return CoreService(db).list_users()


# ── Admin: user state assignments ─────────────────────────────────────────────

@router.get(
    "/admin/user-state-assignments/{user_id}",
    response_model=list[str],
    dependencies=[Depends(require_roles("admin", "manager"))],
)
def get_user_state_assignments(user_id: str, db: Session = Depends(get_db)):
    return CoreService(db).get_user_assigned_states(user_id)


@router.post(
    "/admin/user-state-assignments",
    response_model=UserStateAssignmentOut,
    dependencies=[Depends(require_roles("admin", "manager"))],
)
def assign_state_to_user(payload: UserStateAssignmentIn, db: Session = Depends(get_db)):
    return CoreService(db).assign_state_to_user(payload.user_id, payload.state)


@router.delete(
    "/admin/user-state-assignments/{user_id}/{state}",
    dependencies=[Depends(require_roles("admin", "manager"))],
)
def remove_state_from_user(user_id: str, state: str, db: Session = Depends(get_db)):
    removed = CoreService(db).remove_state_from_user(user_id, state)
    if not removed:
        raise HTTPException(status_code=404, detail="Assignment not found")
    return {"ok": True}
