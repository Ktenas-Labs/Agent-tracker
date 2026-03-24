"""Row-level write authorization for territory-scoped resources."""

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.core import User, UnitAgentAssignment, ReserveUnit, BaseLocation


def assert_unit_write_access(db: Session, user: User, unit_id: str) -> None:
    """Agents may only read/write data for reserve units they are assigned to."""
    if user.role.value in {"admin", "manager"}:
        return
    assigned = (
        db.query(UnitAgentAssignment)
        .filter(UnitAgentAssignment.user_id == user.id, UnitAgentAssignment.unit_id == unit_id)
        .first()
    )
    if not assigned:
        raise HTTPException(status_code=403, detail="Not authorized for this reserve unit")


def assert_agent_is_self(user: User, agent_id: str) -> None:
    """Agents may only act as themselves on conversation/brief records."""
    if user.role.value in {"admin", "manager"}:
        return
    if agent_id != user.id:
        raise HTTPException(status_code=403, detail="Cannot act on behalf of another agent")


def assert_brief_hierarchy_consistent(db: Session, reserve_unit_id: str, base_id: str, region_id: str) -> None:
    """Ensure base/region IDs match the reserve unit (prevents IDOR via mismatched foreign keys)."""
    unit = db.query(ReserveUnit).filter(ReserveUnit.id == reserve_unit_id).first()
    if not unit:
        raise HTTPException(status_code=404, detail="Reserve unit not found")
    if unit.base_id != base_id:
        raise HTTPException(status_code=400, detail="base_id does not match reserve unit")
    base = db.query(BaseLocation).filter(BaseLocation.id == base_id).first()
    if not base:
        raise HTTPException(status_code=404, detail="Base not found")
    if base.region_id != region_id:
        raise HTTPException(status_code=400, detail="region_id does not match base")
