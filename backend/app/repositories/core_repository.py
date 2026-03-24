from sqlalchemy.orm import Session

from app.models.core import Region, BaseLocation, ReserveUnit, UnitAgentAssignment


class CoreRepository:
    def __init__(self, db: Session):
        self.db = db

    def list_regions(self):
        return self.db.query(Region).all()

    def create_region(self, **kwargs):
        obj = Region(**kwargs)
        self.db.add(obj)
        self.db.commit()
        self.db.refresh(obj)
        return obj

    def list_bases(self):
        return self.db.query(BaseLocation).all()

    def create_base(self, **kwargs):
        obj = BaseLocation(**kwargs)
        self.db.add(obj)
        self.db.commit()
        self.db.refresh(obj)
        return obj

    def list_units(self):
        return self.db.query(ReserveUnit).all()

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
