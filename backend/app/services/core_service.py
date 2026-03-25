from sqlalchemy.orm import Session

from app.repositories.core_repository import CoreRepository


class CoreService:
    def __init__(self, db: Session):
        self.repo = CoreRepository(db)

    # ── States ────────────────────────────────────────────────────────────────

    def list_states(self):
        return self.repo.list_states()

    # ── Regions ───────────────────────────────────────────────────────────────

    def list_regions(self):
        return self.repo.list_regions()

    def create_region(self, payload: dict):
        return self.repo.create_region(**payload)

    def update_region(self, region_id: str, updates: dict):
        return self.repo.update_region(region_id, updates)

    def delete_region(self, region_id: str) -> bool:
        return self.repo.delete_region(region_id)

    # ── Bases ─────────────────────────────────────────────────────────────────

    def list_bases(self):
        return self.repo.list_bases()

    def list_bases_for_user(self, user_id: str):
        states = self.repo.get_user_licensed_states(user_id)
        if not states:
            return []
        return self.repo.list_bases_for_states(states)

    def create_base(self, payload: dict):
        return self.repo.create_base(**payload)

    def update_base(self, base_id: str, updates: dict):
        return self.repo.update_base(base_id, updates)

    def delete_base(self, base_id: str) -> bool:
        return self.repo.delete_base(base_id)

    # ── Units ─────────────────────────────────────────────────────────────────

    def list_units(self):
        return self.repo.list_units()

    def list_units_for_user(self, user_id: str):
        states = self.repo.get_user_licensed_states(user_id)
        if not states:
            return self.repo.list_units_for_user(user_id)
        return self.repo.list_units_for_states(states)

    def create_unit(self, payload: dict):
        return self.repo.create_unit(**payload)

    # ── Unit agent assignments ─────────────────────────────────────────────────

    def assign_unit_to_user(self, unit_id: str, user_id: str):
        return self.repo.assign_unit_to_user(unit_id=unit_id, user_id=user_id)

    def remove_unit_from_user(self, unit_id: str, user_id: str) -> bool:
        return self.repo.remove_unit_from_user(unit_id=unit_id, user_id=user_id)

    # ── Unit manager assignments ───────────────────────────────────────────────

    def assign_manager_to_unit(self, unit_id: str, user_id: str):
        return self.repo.assign_manager_to_unit(unit_id=unit_id, user_id=user_id)

    def remove_manager_from_unit(self, unit_id: str, user_id: str) -> bool:
        return self.repo.remove_manager_from_unit(unit_id=unit_id, user_id=user_id)

    # ── User state licenses ────────────────────────────────────────────────────

    def get_user_assigned_states(self, user_id: str) -> list[str]:
        return self.repo.get_user_licensed_states(user_id)

    def assign_state_to_user(self, user_id: str, state_code: str):
        return self.repo.add_state_license(user_id=user_id, state_code=state_code)

    def remove_state_from_user(self, user_id: str, state_code: str) -> bool:
        return self.repo.remove_state_license(user_id=user_id, state_code=state_code)

    # ── Users ──────────────────────────────────────────────────────────────────

    def list_users(self):
        return self.repo.list_users()

    def create_user(self, payload: dict):
        return self.repo.create_user(**payload)

    def update_user(self, user_id: str, updates: dict):
        return self.repo.update_user(user_id, updates)

    def delete_user(self, user_id: str) -> bool:
        return self.repo.delete_user(user_id)

    def get_state_coverage(self) -> list[dict]:
        return self.repo.get_state_coverage()
