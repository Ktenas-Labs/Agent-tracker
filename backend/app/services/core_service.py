from sqlalchemy.orm import Session

from app.repositories.core_repository import CoreRepository


class CoreService:
    def __init__(self, db: Session):
        self.repo = CoreRepository(db)

    def list_regions(self):
        return self.repo.list_regions()

    def create_region(self, payload: dict):
        return self.repo.create_region(**payload)

    def list_bases(self):
        return self.repo.list_bases()

    def create_base(self, payload: dict):
        return self.repo.create_base(**payload)

    def list_units(self):
        return self.repo.list_units()

    def list_units_for_user(self, user_id: str):
        return self.repo.list_units_for_user(user_id)

    def create_unit(self, payload: dict):
        return self.repo.create_unit(**payload)

    def assign_unit_to_user(self, unit_id: str, user_id: str):
        return self.repo.assign_unit_to_user(unit_id=unit_id, user_id=user_id)
