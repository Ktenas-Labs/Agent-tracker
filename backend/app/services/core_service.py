from sqlalchemy.orm import Session

from app.repositories.core_repository import CoreRepository


class CoreService:
    def __init__(self, db: Session):
        self.repo = CoreRepository(db)

    # ── Regions ──────────────────────────────────────────────────────────────

    def list_regions(self):
        return self.repo.list_regions()

    def create_region(self, payload: dict):
        return self.repo.create_region(**payload)

    # ── Bases ────────────────────────────────────────────────────────────────

    def list_bases(self):
        return self.repo.list_bases()

    def list_bases_for_user(self, user_id: str):
        states = self.repo.get_user_assigned_states(user_id)
        if not states:
            return []
        return self.repo.list_bases_for_states(states)

    def create_base(self, payload: dict):
        return self.repo.create_base(**payload)

    # ── Units ────────────────────────────────────────────────────────────────

    def list_units(self):
        return self.repo.list_units()

    def list_units_for_user(self, user_id: str):
        states = self.repo.get_user_assigned_states(user_id)
        if not states:
            return []
        return self.repo.list_units_for_states(states)

    def create_unit(self, payload: dict):
        return self.repo.create_unit(**payload)

    def assign_unit_to_user(self, unit_id: str, user_id: str):
        return self.repo.assign_unit_to_user(unit_id=unit_id, user_id=user_id)

    # ── User state assignments ────────────────────────────────────────────────

    def get_user_assigned_states(self, user_id: str) -> list[str]:
        return self.repo.get_user_assigned_states(user_id)

    def assign_state_to_user(self, user_id: str, state: str):
        return self.repo.assign_state_to_user(user_id=user_id, state=state)

    def remove_state_from_user(self, user_id: str, state: str) -> bool:
        return self.repo.remove_state_from_user(user_id=user_id, state=state)

    # ── Users ────────────────────────────────────────────────────────────────

    def list_users(self):
        return self.repo.list_users()
