from sqlalchemy.orm import Session

from app.models.core import Region, BaseLocation, ReserveUnit, UnitAgentAssignment, User, UserStateAssignment


class CoreRepository:
    def __init__(self, db: Session):
        self.db = db

    # ── Regions ──────────────────────────────────────────────────────────────

    def list_regions(self):
        return self.db.query(Region).all()

    def create_region(self, **kwargs):
        obj = Region(**kwargs)
        self.db.add(obj)
        self.db.commit()
        self.db.refresh(obj)
        return obj

    # ── Bases ────────────────────────────────────────────────────────────────

    def list_bases(self):
        return self.db.query(BaseLocation).all()

    def list_bases_for_states(self, states: list[str]):
        return self.db.query(BaseLocation).filter(BaseLocation.state.in_(states)).all()

    def create_base(self, **kwargs):
        obj = BaseLocation(**kwargs)
        self.db.add(obj)
        self.db.commit()
        self.db.refresh(obj)
        return obj

    # ── Units ────────────────────────────────────────────────────────────────

    def list_units(self):
        return self.db.query(ReserveUnit).all()

    def list_units_for_states(self, states: list[str]):
        return (
            self.db.query(ReserveUnit)
            .join(BaseLocation, BaseLocation.id == ReserveUnit.base_id)
            .filter(BaseLocation.state.in_(states))
            .all()
        )

    def list_units_for_user(self, user_id: str):
        return (
            self.db.query(ReserveUnit)
            .join(UnitAgentAssignment, UnitAgentAssignment.unit_id == ReserveUnit.id)
            .filter(UnitAgentAssignment.user_id == user_id)
            .all()
        )

    def create_unit(self, **kwargs):
        obj = ReserveUnit(**kwargs)
        self.db.add(obj)
        self.db.commit()
        self.db.refresh(obj)
        return obj

    def assign_unit_to_user(self, unit_id: str, user_id: str):
        existing = (
            self.db.query(UnitAgentAssignment)
            .filter(UnitAgentAssignment.unit_id == unit_id, UnitAgentAssignment.user_id == user_id)
            .first()
        )
        if existing:
            return existing
        obj = UnitAgentAssignment(unit_id=unit_id, user_id=user_id)
        self.db.add(obj)
        self.db.commit()
        self.db.refresh(obj)
        return obj

    # ── User state assignments ────────────────────────────────────────────────

    def get_user_assigned_states(self, user_id: str) -> list[str]:
        rows = (
            self.db.query(UserStateAssignment)
            .filter(UserStateAssignment.user_id == user_id)
            .all()
        )
        return [r.state for r in rows]

    def assign_state_to_user(self, user_id: str, state: str):
        existing = (
            self.db.query(UserStateAssignment)
            .filter(UserStateAssignment.user_id == user_id, UserStateAssignment.state == state)
            .first()
        )
        if existing:
            return existing
        obj = UserStateAssignment(user_id=user_id, state=state)
        self.db.add(obj)
        self.db.commit()
        self.db.refresh(obj)
        return obj

    def remove_state_from_user(self, user_id: str, state: str) -> bool:
        obj = (
            self.db.query(UserStateAssignment)
            .filter(UserStateAssignment.user_id == user_id, UserStateAssignment.state == state)
            .first()
        )
        if not obj:
            return False
        self.db.delete(obj)
        self.db.commit()
        return True

    # ── Users ────────────────────────────────────────────────────────────────

    def list_users(self):
        return self.db.query(User).order_by(User.last_name, User.first_name).all()
