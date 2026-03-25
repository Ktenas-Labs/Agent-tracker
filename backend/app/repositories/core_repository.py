from sqlalchemy.orm import Session

from app.models.core import (
    Region, BaseLocation, ReserveUnit,
    UnitAgent, UnitManager,
    UserStateLicense,
    User, State,
)


class CoreRepository:
    def __init__(self, db: Session):
        self.db = db

    # ── States ────────────────────────────────────────────────────────────────

    def list_states(self) -> list[State]:
        return self.db.query(State).order_by(State.name).all()

    # ── Regions ───────────────────────────────────────────────────────────────

    def list_regions(self) -> list[Region]:
        return self.db.query(Region).order_by(Region.name).all()

    def create_region(self, **kwargs) -> Region:
        obj = Region(**kwargs)
        self.db.add(obj)
        self.db.commit()
        self.db.refresh(obj)
        return obj

    def update_region(self, region_id: str, updates: dict) -> Region | None:
        obj = self.db.query(Region).filter(Region.id == region_id).first()
        if not obj:
            return None
        for k, v in updates.items():
            setattr(obj, k, v)
        self.db.commit()
        self.db.refresh(obj)
        return obj

    def delete_region(self, region_id: str) -> bool:
        obj = self.db.query(Region).filter(Region.id == region_id).first()
        if not obj:
            return False
        self.db.delete(obj)
        self.db.commit()
        return True

    # ── Bases ─────────────────────────────────────────────────────────────────

    def list_bases(self) -> list[BaseLocation]:
        return self.db.query(BaseLocation).order_by(BaseLocation.name).all()

    def list_bases_for_states(self, states: list[str]) -> list[BaseLocation]:
        return (
            self.db.query(BaseLocation)
            .filter(BaseLocation.state.in_(states))
            .order_by(BaseLocation.name)
            .all()
        )

    def create_base(self, **kwargs) -> BaseLocation:
        obj = BaseLocation(**kwargs)
        self.db.add(obj)
        self.db.commit()
        self.db.refresh(obj)
        return obj

    def update_base(self, base_id: str, updates: dict) -> BaseLocation | None:
        obj = self.db.query(BaseLocation).filter(BaseLocation.id == base_id).first()
        if not obj:
            return None
        for k, v in updates.items():
            setattr(obj, k, v)
        self.db.commit()
        self.db.refresh(obj)
        return obj

    def delete_base(self, base_id: str) -> bool:
        obj = self.db.query(BaseLocation).filter(BaseLocation.id == base_id).first()
        if not obj:
            return False
        self.db.delete(obj)
        self.db.commit()
        return True

    # ── Units ─────────────────────────────────────────────────────────────────

    def list_units(self) -> list[ReserveUnit]:
        return self.db.query(ReserveUnit).order_by(ReserveUnit.name).all()

    def list_units_for_states(self, states: list[str]) -> list[ReserveUnit]:
        return (
            self.db.query(ReserveUnit)
            .join(BaseLocation, BaseLocation.id == ReserveUnit.base_id)
            .filter(BaseLocation.state.in_(states))
            .order_by(ReserveUnit.name)
            .all()
        )

    def list_units_for_user(self, user_id: str) -> list[ReserveUnit]:
        return (
            self.db.query(ReserveUnit)
            .join(UnitAgent, UnitAgent.unit_id == ReserveUnit.id)
            .filter(UnitAgent.user_id == user_id)
            .order_by(ReserveUnit.name)
            .all()
        )

    def create_unit(self, **kwargs) -> ReserveUnit:
        obj = ReserveUnit(**kwargs)
        self.db.add(obj)
        self.db.commit()
        self.db.refresh(obj)
        return obj

    # ── Unit agent assignments ─────────────────────────────────────────────────

    def assign_unit_to_user(self, unit_id: str, user_id: str) -> UnitAgent:
        existing = (
            self.db.query(UnitAgent)
            .filter(UnitAgent.unit_id == unit_id, UnitAgent.user_id == user_id)
            .first()
        )
        if existing:
            return existing
        obj = UnitAgent(unit_id=unit_id, user_id=user_id)
        self.db.add(obj)
        self.db.commit()
        self.db.refresh(obj)
        return obj

    def remove_unit_from_user(self, unit_id: str, user_id: str) -> bool:
        obj = (
            self.db.query(UnitAgent)
            .filter(UnitAgent.unit_id == unit_id, UnitAgent.user_id == user_id)
            .first()
        )
        if not obj:
            return False
        self.db.delete(obj)
        self.db.commit()
        return True

    # ── Unit manager assignments ───────────────────────────────────────────────

    def assign_manager_to_unit(self, unit_id: str, user_id: str) -> UnitManager:
        existing = (
            self.db.query(UnitManager)
            .filter(UnitManager.unit_id == unit_id, UnitManager.user_id == user_id)
            .first()
        )
        if existing:
            return existing
        obj = UnitManager(unit_id=unit_id, user_id=user_id)
        self.db.add(obj)
        self.db.commit()
        self.db.refresh(obj)
        return obj

    def remove_manager_from_unit(self, unit_id: str, user_id: str) -> bool:
        obj = (
            self.db.query(UnitManager)
            .filter(UnitManager.unit_id == unit_id, UnitManager.user_id == user_id)
            .first()
        )
        if not obj:
            return False
        self.db.delete(obj)
        self.db.commit()
        return True

    # ── User state licenses ────────────────────────────────────────────────────

    def get_user_licensed_states(self, user_id: str) -> list[str]:
        rows = (
            self.db.query(UserStateLicense)
            .filter(UserStateLicense.user_id == user_id)
            .all()
        )
        return [r.state_code for r in rows]

    def add_state_license(self, user_id: str, state_code: str) -> UserStateLicense:
        existing = (
            self.db.query(UserStateLicense)
            .filter(UserStateLicense.user_id == user_id, UserStateLicense.state_code == state_code)
            .first()
        )
        if existing:
            return existing
        obj = UserStateLicense(user_id=user_id, state_code=state_code)
        self.db.add(obj)
        self.db.commit()
        self.db.refresh(obj)
        return obj

    def remove_state_license(self, user_id: str, state_code: str) -> bool:
        obj = (
            self.db.query(UserStateLicense)
            .filter(UserStateLicense.user_id == user_id, UserStateLicense.state_code == state_code)
            .first()
        )
        if not obj:
            return False
        self.db.delete(obj)
        self.db.commit()
        return True

    # ── Users ──────────────────────────────────────────────────────────────────

    def list_users(self) -> list[User]:
        return self.db.query(User).order_by(User.last_name, User.first_name).all()

    def get_state_coverage(self) -> list[dict]:
        """Return each state that has ≥1 agent assignment, with its agent list."""
        rows = (
            self.db.query(UserStateLicense, User, State)
            .join(User, User.id == UserStateLicense.user_id)
            .join(State, State.code == UserStateLicense.state_code)
            .order_by(State.name, User.last_name, User.first_name)
            .all()
        )
        coverage: dict[str, dict] = {}
        for _lic, user, state in rows:
            if state.code not in coverage:
                coverage[state.code] = {
                    "state_code": state.code,
                    "state_name": state.name,
                    "agents": [],
                }
            coverage[state.code]["agents"].append({
                "id": user.id,
                "first_name": user.first_name,
                "last_name": user.last_name,
                "role": user.role.value,
                "is_admin": user.is_admin,
            })
        return list(coverage.values())

    def create_user(self, **kwargs) -> User:
        from app.models.core import UserRole
        role_val = kwargs.pop("role", "agent")
        kwargs["role"] = UserRole(role_val)
        import uuid as _uuid
        if "id" not in kwargs:
            kwargs["id"] = str(_uuid.uuid4())
        obj = User(**kwargs)
        self.db.add(obj)
        self.db.commit()
        self.db.refresh(obj)
        return obj

    def update_user(self, user_id: str, updates: dict) -> User | None:
        from app.models.core import UserRole
        obj = self.db.query(User).filter(User.id == user_id).first()
        if not obj:
            return None
        if "role" in updates:
            updates["role"] = UserRole(updates["role"])
        for k, v in updates.items():
            setattr(obj, k, v)
        self.db.commit()
        self.db.refresh(obj)
        return obj

    def delete_user(self, user_id: str) -> bool:
        obj = self.db.query(User).filter(User.id == user_id).first()
        if not obj:
            return False
        self.db.delete(obj)
        self.db.commit()
        return True

    # ── Backward-compat aliases used by CoreService ────────────────────────────

    def get_user_assigned_states(self, user_id: str) -> list[str]:
        return self.get_user_licensed_states(user_id)

    def assign_state_to_user(self, user_id: str, state: str) -> UserStateLicense:
        return self.add_state_license(user_id=user_id, state_code=state)

    def remove_state_from_user(self, user_id: str, state: str) -> bool:
        return self.remove_state_license(user_id=user_id, state_code=state)
