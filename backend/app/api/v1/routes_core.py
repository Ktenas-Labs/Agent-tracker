from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.schemas.common import (
    StateOut,
    RegionIn, RegionOut, RegionUpdate,
    BaseIn, BaseOut, BaseUpdate,
    UnitIn, UnitOut,
    UnitAgentIn, UnitAgentOut,
    UnitManagerIn, UnitManagerOut,
    UserOut, UserCreate, UserUpdate,
    UserStateLicenseIn, UserStateLicenseOut,
)
from app.services.core_service import CoreService
from app.api.deps import require_roles, get_current_user
from app.models.core import User

router = APIRouter()


@router.get("/health")
def health():
    return {"status": "ok"}


# ── States ─────────────────────────────────────────────────────────────────────

@router.get("/states", response_model=list[StateOut])
def list_states(db: Session = Depends(get_db)):
    return CoreService(db).list_states()


# ── Regions ────────────────────────────────────────────────────────────────────

@router.get("/regions", response_model=list[RegionOut], dependencies=[Depends(require_roles("agent"))])
def list_regions(db: Session = Depends(get_db)):
    return CoreService(db).list_regions()


@router.post("/regions", response_model=RegionOut, dependencies=[Depends(require_roles("manager"))])
def create_region(payload: RegionIn, db: Session = Depends(get_db)):
    return CoreService(db).create_region(payload.model_dump())


@router.put("/regions/{region_id}", response_model=RegionOut, dependencies=[Depends(require_roles("manager"))])
def update_region(region_id: str, payload: RegionUpdate, db: Session = Depends(get_db)):
    updates = {k: v for k, v in payload.model_dump().items() if v is not None}
    result = CoreService(db).update_region(region_id, updates)
    if not result:
        raise HTTPException(status_code=404, detail="Region not found")
    return result


@router.delete("/regions/{region_id}", dependencies=[Depends(require_roles("manager"))])
def delete_region(region_id: str, db: Session = Depends(get_db)):
    ok = CoreService(db).delete_region(region_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Region not found")
    return {"ok": True}


# ── Bases ──────────────────────────────────────────────────────────────────────

@router.get("/bases", response_model=list[BaseOut], dependencies=[Depends(require_roles("agent"))])
def list_bases(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    service = CoreService(db)
    if user.is_admin or user.is_manager:
        return service.list_bases()
    return service.list_bases_for_user(user.id)


@router.post("/bases", response_model=BaseOut, dependencies=[Depends(require_roles("manager"))])
def create_base(payload: BaseIn, db: Session = Depends(get_db)):
    return CoreService(db).create_base(payload.model_dump())


@router.put("/bases/{base_id}", response_model=BaseOut, dependencies=[Depends(require_roles("manager"))])
def update_base(base_id: str, payload: BaseUpdate, db: Session = Depends(get_db)):
    updates = {k: v for k, v in payload.model_dump().items() if v is not None}
    result = CoreService(db).update_base(base_id, updates)
    if not result:
        raise HTTPException(status_code=404, detail="Base not found")
    return result


@router.delete("/bases/{base_id}", dependencies=[Depends(require_roles("manager"))])
def delete_base(base_id: str, db: Session = Depends(get_db)):
    ok = CoreService(db).delete_base(base_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Base not found")
    return {"ok": True}


# ── Units ──────────────────────────────────────────────────────────────────────

@router.get("/units", response_model=list[UnitOut], dependencies=[Depends(require_roles("agent"))])
def list_units(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    service = CoreService(db)
    if user.is_admin or user.is_manager:
        return service.list_units()
    return service.list_units_for_user(user.id)


@router.post("/units", response_model=UnitOut, dependencies=[Depends(require_roles("agent"))])
def create_unit(payload: UnitIn, db: Session = Depends(get_db)):
    try:
        return CoreService(db).create_unit(payload.model_dump())
    except Exception as ex:
        raise HTTPException(status_code=400, detail=str(ex)) from ex


@router.get("/units/my", response_model=list[UnitOut], dependencies=[Depends(require_roles("agent"))])
def list_my_units(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    service = CoreService(db)
    if user.is_admin or user.is_manager:
        return service.list_units()
    return service.list_units_for_user(user.id)


# ── Admin: unit assignments ────────────────────────────────────────────────────

@router.post("/admin/unit-assignments", response_model=UnitAgentOut, dependencies=[Depends(require_roles("manager"))])
def assign_unit_to_agent(payload: UnitAgentIn, db: Session = Depends(get_db)):
    return CoreService(db).assign_unit_to_user(payload.unit_id, payload.user_id)


@router.post("/admin/unit-manager-assignments", response_model=UnitManagerOut, dependencies=[Depends(require_roles("manager"))])
def assign_unit_to_manager(payload: UnitManagerIn, db: Session = Depends(get_db)):
    return CoreService(db).assign_manager_to_unit(payload.unit_id, payload.user_id)


# ── Admin: users ───────────────────────────────────────────────────────────────

@router.get("/admin/users", response_model=list[UserOut], dependencies=[Depends(require_roles("manager"))])
def list_users(db: Session = Depends(get_db)):
    return CoreService(db).list_users()


@router.post("/admin/users", response_model=UserOut, dependencies=[Depends(require_roles("manager"))])
def create_user(payload: UserCreate, db: Session = Depends(get_db)):
    try:
        return CoreService(db).create_user(payload.model_dump())
    except Exception as ex:
        raise HTTPException(status_code=400, detail=str(ex)) from ex


@router.put("/admin/users/{user_id}", response_model=UserOut, dependencies=[Depends(require_roles("manager"))])
def update_user(user_id: str, payload: UserUpdate, db: Session = Depends(get_db)):
    updates = {k: v for k, v in payload.model_dump().items() if v is not None}
    result = CoreService(db).update_user(user_id, updates)
    if not result:
        raise HTTPException(status_code=404, detail="User not found")
    return result


@router.delete("/admin/users/{user_id}", dependencies=[Depends(require_roles("manager"))])
def delete_user(user_id: str, db: Session = Depends(get_db)):
    ok = CoreService(db).delete_user(user_id)
    if not ok:
        raise HTTPException(status_code=404, detail="User not found")
    return {"ok": True}


@router.get("/admin/state-coverage", dependencies=[Depends(require_roles("manager"))])
def get_state_coverage(db: Session = Depends(get_db)):
    """Per-state summary: which agents are assigned to each state."""
    return CoreService(db).get_state_coverage()


# ── Admin: state licenses ──────────────────────────────────────────────────────

@router.get(
    "/admin/user-state-licenses/{user_id}",
    response_model=list[str],
    dependencies=[Depends(require_roles("manager"))],
)
def get_user_state_licenses(user_id: str, db: Session = Depends(get_db)):
    return CoreService(db).get_user_assigned_states(user_id)


@router.post(
    "/admin/user-state-licenses",
    response_model=UserStateLicenseOut,
    dependencies=[Depends(require_roles("manager"))],
)
def add_state_license(payload: UserStateLicenseIn, db: Session = Depends(get_db)):
    return CoreService(db).assign_state_to_user(payload.user_id, payload.state_code)


@router.delete(
    "/admin/user-state-licenses/{user_id}/{state_code}",
    dependencies=[Depends(require_roles("manager"))],
)
def remove_state_license(user_id: str, state_code: str, db: Session = Depends(get_db)):
    removed = CoreService(db).remove_state_from_user(user_id, state_code)
    if not removed:
        raise HTTPException(status_code=404, detail="License not found")
    return {"ok": True}


# ── Current-user state assignments ────────────────────────────────────────────

@router.get("/me/state-assignments", response_model=list[str])
def get_my_state_assignments(
    user: User = Depends(get_current_user), db: Session = Depends(get_db)
):
    """Return the state assignments for the currently authenticated user."""
    return CoreService(db).get_user_assigned_states(user.id)


# ── Backward-compat aliases (old route paths still work) ──────────────────────

@router.get(
    "/admin/user-state-assignments/{user_id}",
    response_model=list[str],
    dependencies=[Depends(require_roles("manager"))],
    include_in_schema=False,
)
def get_user_state_assignments_compat(user_id: str, db: Session = Depends(get_db)):
    return CoreService(db).get_user_assigned_states(user_id)


@router.post(
    "/admin/unit-assignments",
    response_model=UnitAgentOut,
    dependencies=[Depends(require_roles("manager"))],
    include_in_schema=False,
)
def assign_unit_compat(payload: UnitAgentIn, db: Session = Depends(get_db)):
    return CoreService(db).assign_unit_to_user(payload.unit_id, payload.user_id)
