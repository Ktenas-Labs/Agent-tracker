from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.schemas.operations import (
    ContactIn,
    ContactOut,
    ConversationIn,
    ConversationOut,
    BriefIn,
    BriefOut,
)
from app.services.operations_service import OperationsService
from app.services.authorization import (
    assert_unit_write_access,
    assert_agent_is_self,
    assert_brief_hierarchy_consistent,
)
from app.api.deps import require_roles, get_current_user
from app.models.core import User

router = APIRouter()


@router.get("/contacts", response_model=list[ContactOut], dependencies=[Depends(require_roles("admin", "manager", "agent"))])
def list_contacts(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    service = OperationsService(db)
    if user.role.value in {"admin", "manager"}:
        return service.list_contacts()
    return service.list_contacts_for_user(user.id)


@router.post("/contacts", response_model=ContactOut, dependencies=[Depends(require_roles("admin", "manager", "agent"))])
def create_contact(
    payload: ContactIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    assert_unit_write_access(db, user, payload.reserve_unit_id)
    return OperationsService(db).create_contact(payload.model_dump())


@router.get("/conversations", response_model=list[ConversationOut], dependencies=[Depends(require_roles("admin", "manager", "agent"))])
def list_conversations(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    service = OperationsService(db)
    if user.role.value in {"admin", "manager"}:
        return service.list_conversations()
    return service.list_conversations_for_user(user.id)


@router.post("/conversations", response_model=ConversationOut, dependencies=[Depends(require_roles("admin", "manager", "agent"))])
def create_conversation(
    payload: ConversationIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    assert_unit_write_access(db, user, payload.reserve_unit_id)
    assert_agent_is_self(user, payload.agent_id)
    return OperationsService(db).create_conversation(payload.model_dump())


@router.get("/briefs", response_model=list[BriefOut], dependencies=[Depends(require_roles("admin", "manager", "agent"))])
def list_briefs(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    service = OperationsService(db)
    if user.role.value in {"admin", "manager"}:
        return service.list_briefs()
    return service.list_briefs_for_user(user.id)


@router.post("/briefs", response_model=BriefOut, dependencies=[Depends(require_roles("admin", "manager", "agent"))])
def create_brief(
    payload: BriefIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    assert_unit_write_access(db, user, payload.reserve_unit_id)
    assert_agent_is_self(user, payload.assigned_agent_id)
    assert_brief_hierarchy_consistent(db, payload.reserve_unit_id, payload.base_id, payload.region_id)
    return OperationsService(db).create_brief(payload.model_dump())
