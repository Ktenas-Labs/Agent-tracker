from datetime import date

from sqlalchemy.orm import Session

from app.repositories.operations_repository import OperationsRepository


class OperationsService:
    def __init__(self, db: Session):
        self.repo = OperationsRepository(db)

    # ── Contacts ──────────────────────────────────────────────────────────────

    def list_contacts(self):
        return self.repo.list_contacts()

    def list_contacts_for_user(self, user_id: str):
        return self.repo.list_contacts_for_user(user_id)

    def create_contact(self, payload: dict):
        unit_ids = payload.pop("unit_ids", [])
        return self.repo.create_contact(unit_ids=unit_ids, **payload)

    # ── Conversation logs ─────────────────────────────────────────────────────

    def list_conversations(self):
        return self.repo.list_conversations()

    def list_conversations_for_user(self, user_id: str):
        return self.repo.list_conversations_for_user(user_id)

    def create_conversation(self, payload: dict):
        return self.repo.create_conversation(**payload)

    # ── Briefs ────────────────────────────────────────────────────────────────

    def list_briefs(self):
        return self.repo.list_briefs()

    def list_briefs_for_user(self, user_id: str):
        return self.repo.list_briefs_for_user(user_id)

    def get_brief(self, brief_id: str):
        return self.repo.get_brief(brief_id)

    def create_brief(self, payload: dict):
        unit_ids = payload.pop("unit_ids", [])
        contact_ids = payload.pop("contact_ids", [])
        return self.repo.create_brief(unit_ids=unit_ids, contact_ids=contact_ids, **payload)

    def update_brief(self, brief_id: str, payload: dict):
        # unit_ids / contact_ids are junction-only — not bare columns
        payload.pop("unit_ids", None)
        payload.pop("contact_ids", None)
        return self.repo.update_brief(brief_id, **payload)

    # ── Trips ─────────────────────────────────────────────────────────────────

    def list_trips(self):
        return self.repo.list_trips()

    def list_trips_for_agent(self, agent_id: str):
        return self.repo.list_trips_for_agent(agent_id)

    def get_trip(self, trip_id: str):
        return self.repo.get_trip(trip_id)

    def create_trip(self, payload: dict):
        brief_ids = payload.pop("brief_ids", [])
        return self.repo.create_trip(brief_ids=brief_ids, **payload)

    def update_trip(self, trip_id: str, payload: dict):
        payload.pop("brief_ids", None)
        return self.repo.update_trip(trip_id, **payload)

    def add_brief_to_trip(self, trip_id: str, brief_id: str) -> bool:
        return self.repo.add_brief_to_trip(trip_id, brief_id)

    def remove_brief_from_trip(self, trip_id: str, brief_id: str) -> bool:
        return self.repo.remove_brief_from_trip(trip_id, brief_id)

    def list_briefs_for_trip(self, trip_id: str):
        return self.repo.list_briefs_for_trip(trip_id)

    # ── Nearby-unit suggestions ───────────────────────────────────────────────

    def suggest_nearby_units(
        self,
        lat: float,
        lon: float,
        radius_miles: float = 150.0,
        start_date: date | None = None,
        end_date: date | None = None,
        exclude_unit_ids: list[str] | None = None,
    ) -> list[dict]:
        return self.repo.find_nearby_units(
            lat=lat,
            lon=lon,
            radius_miles=radius_miles,
            start_date=start_date,
            end_date=end_date,
            exclude_unit_ids=exclude_unit_ids,
        )
