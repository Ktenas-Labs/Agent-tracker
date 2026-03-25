import csv
import io
from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.db.session import get_db
from app.models.core import ReserveUnit, Brief, BriefUnit, ConversationLog, BriefStatus, UnitAgent, User
from app.api.deps import require_roles, get_current_user

router = APIRouter()


@router.get("/reports/dashboard", dependencies=[Depends(require_roles("agent"))])
def dashboard(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    if user.is_admin or user.is_manager:
        units_total = db.query(func.count(ReserveUnit.id)).scalar() or 0
        briefs_total = db.query(func.count(Brief.id)).scalar() or 0
        conversations_total = db.query(func.count(ConversationLog.id)).scalar() or 0
        completed_briefs = db.query(func.count(Brief.id)).filter(Brief.status == BriefStatus.completed).scalar() or 0
    else:
        units_total = (
            db.query(func.count(ReserveUnit.id))
            .join(UnitAgent, UnitAgent.unit_id == ReserveUnit.id)
            .filter(UnitAgent.user_id == user.id)
            .scalar()
            or 0
        )
        briefs_total = (
            db.query(func.count(Brief.id))
            .join(BriefUnit, BriefUnit.brief_id == Brief.id)
            .join(UnitAgent, UnitAgent.unit_id == BriefUnit.unit_id)
            .filter(UnitAgent.user_id == user.id)
            .scalar()
            or 0
        )
        conversations_total = (
            db.query(func.count(ConversationLog.id))
            .join(UnitAgent, UnitAgent.unit_id == ConversationLog.unit_id)
            .filter(UnitAgent.user_id == user.id)
            .scalar()
            or 0
        )
        completed_briefs = (
            db.query(func.count(Brief.id))
            .join(BriefUnit, BriefUnit.brief_id == Brief.id)
            .join(UnitAgent, UnitAgent.unit_id == BriefUnit.unit_id)
            .filter(UnitAgent.user_id == user.id, Brief.status == BriefStatus.completed)
            .scalar()
            or 0
        )
    return {
        "units_total": units_total,
        "briefs_total": briefs_total,
        "conversations_total": conversations_total,
        "completed_briefs": completed_briefs,
    }


@router.get("/reports/units-by-status", dependencies=[Depends(require_roles("manager"))])
def units_by_status(db: Session = Depends(get_db)):
    rows = db.query(ReserveUnit.crm_status, func.count(ReserveUnit.id)).group_by(ReserveUnit.crm_status).all()
    return [{"status": r[0].value if hasattr(r[0], "value") else str(r[0]), "count": r[1]} for r in rows]


@router.get("/reports/briefs-by-agent", dependencies=[Depends(require_roles("manager"))])
def briefs_by_agent(db: Session = Depends(get_db)):
    rows = db.query(Brief.assigned_agent_id, func.count(Brief.id)).group_by(Brief.assigned_agent_id).all()
    return [{"agent_id": r[0], "brief_count": r[1]} for r in rows]


@router.get("/reports/export.csv", dependencies=[Depends(require_roles("manager"))])
def export_csv(db: Session = Depends(get_db)):
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["unit_id", "unit_name", "crm_status"])
    for unit in db.query(ReserveUnit).all():
        writer.writerow([unit.id, unit.name, unit.crm_status.value if hasattr(unit.crm_status, "value") else unit.crm_status])
    output.seek(0)
    return StreamingResponse(iter([output.getvalue()]), media_type="text/csv")


@router.get("/reports/my-summary", dependencies=[Depends(require_roles("agent"))])
def my_summary(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    if user.is_admin or user.is_manager:
        return dashboard(db, user)
    assigned_units = (
        db.query(ReserveUnit.id, ReserveUnit.name, ReserveUnit.crm_status)
        .join(UnitAgent, UnitAgent.unit_id == ReserveUnit.id)
        .filter(UnitAgent.user_id == user.id)
        .all()
    )
    return {
        "units": [{"id": u[0], "name": u[1], "crm_status": u[2].value if hasattr(u[2], "value") else str(u[2])} for u in assigned_units],
        "units_total": len(assigned_units),
    }
