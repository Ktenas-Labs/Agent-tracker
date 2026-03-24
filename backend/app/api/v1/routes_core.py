from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.schemas.common import RegionIn, RegionOut, BaseIn, BaseOut, UnitIn, UnitOut, UnitAssignmentIn, UnitAssignmentOut
from app.services.core_service import CoreService
from app.api.deps import require_roles, get_current_user
from app.models.core import User

router = APIRouter()


@router.get("/health")
def health():
    return {"status": "ok"}


@router.get("/regions", response_model=list[RegionOut], dependencies=[Depends(require_roles("admin", "manager", "agent"))])
def list_regions(db: Session = Depends(get_db)):
    return CoreService(db).list_regions()


@router.post("/regions", response_model=RegionOut, dependencies=[Depends(require_roles("admin", "manager"))])
def create_region(payload: RegionIn, db: Session = Depends(get_db)):
    return CoreService(db).create_region(payload.model_dump())


@router.get("/bases", response_model=list[BaseOut], dependencies=[Depends(require_roles("admin", "manager", "agent"))])
def list_bases(db: Session = Depends(get_db)):
    return CoreService(db).list_bases()


@router.post("/bases", response_model=BaseOut, dependencies=[Depends(require_roles("admin", "manager"))])
def create_base(payload: BaseIn, db: Session = Depends(get_db)):
    return CoreService(db).create_base(payload.model_dump())


@router.get("/units", response_model=list[UnitOut], dependencies=[Depends(require_roles("admin", "manager", "agent"))])
def list_units(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    service = CoreService(db)
    if user.role.value in {"admin", "manager"}:
        return service.list_units()
    return service.list_units_for_user(user.id)


@router.post("/units", response_model=UnitOut, dependencies=[Depends(require_roles("admin", "manager", "agent"))])
def create_unit(payload: UnitIn, db: Session = Depends(get_db)):
    try:
        return CoreService(db).create_unit(payload.model_dump())
    except Exception as ex:
        raise HTTPException(status_code=400, detail=str(ex)) from ex


@router.post("/admin/regions", response_model=RegionOut, dependencies=[Depends(require_roles("admin", "manager"))])
def create_region_guarded(payload: RegionIn, db: Session = Depends(get_db)):
    return CoreService(db).create_region(payload.model_dump())


@router.get("/units/my", response_model=list[UnitOut])
def list_my_units(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    service = CoreService(db)
    if user.role.value in {"admin", "manager"}:
        return service.list_units()
    return service.list_units_for_user(user.id)


@router.post("/admin/unit-assignments", response_model=UnitAssignmentOut, dependencies=[Depends(require_roles("admin", "manager"))])
def assign_unit(payload: UnitAssignmentIn, db: Session = Depends(get_db)):
    return CoreService(db).assign_unit_to_user(payload.unit_id, payload.user_id)
