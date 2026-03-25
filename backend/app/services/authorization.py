"""Row-level write authorization for territory-scoped resources."""

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.core import User, UnitAgent


def assert_unit_write_access(db: Session, user: User, unit_id: str) -> None:
    """Agents may only read/write data for reserve units they are assigned to."""
    if user.is_admin or user.is_manager:
        return
    assigned = (
        db.query(UnitAgent)
        .filter(UnitAgent.user_id == user.id, UnitAgent.unit_id == unit_id)
        .first()
    )
    if not assigned:
        raise HTTPException(status_code=403, detail="Not authorized for this reserve unit")


def assert_agent_is_self(user: User, agent_id: str) -> None:
    """Agents may only act as themselves on conversation/brief records."""
    if user.is_admin or user.is_manager:
        return
    if agent_id != user.id:
        raise HTTPException(status_code=403, detail="Cannot act on behalf of another agent")
