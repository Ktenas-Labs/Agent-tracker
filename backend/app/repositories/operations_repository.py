import math
from datetime import date

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.core import (
    Contact, ContactUnit,
    ConversationLog,
    Brief, BriefUnit, BriefContact,
    UnitAgent,
    Trip, TripBrief,
    BaseLocation, ReserveUnit,
)


class OperationsRepository:
    def __init__(self, db: Session):
        self.db = db

    # ── Contacts ──────────────────────────────────────────────────────────────

    def list_contacts(self) -> list[Contact]:
        return self.db.query(Contact).order_by(Contact.last_name, Contact.first_name).all()

    def list_contacts_for_user(self, user_id: str) -> list[Contact]:
        """Contacts associated with units the user is assigned to."""
        return (
            self.db.query(Contact)
            .join(ContactUnit, ContactUnit.contact_id == Contact.id)
            .join(UnitAgent, UnitAgent.unit_id == ContactUnit.unit_id)
            .filter(UnitAgent.user_id == user_id)
            .distinct()
            .order_by(Contact.last_name, Contact.first_name)
            .all()
        )

    def create_contact(self, unit_ids: list[str], **kwargs) -> Contact:
        obj = Contact(**kwargs)
        self.db.add(obj)
        self.db.flush()  # get obj.id before junction inserts
        for uid in unit_ids:
            self.db.add(ContactUnit(contact_id=obj.id, unit_id=uid))
        self.db.commit()
        self.db.refresh(obj)
        return obj

    # ── Conversation Logs ──────────────────────────────────────────────────────

    def list_conversations(self) -> list[ConversationLog]:
        return (
            self.db.query(ConversationLog)
            .order_by(ConversationLog.occurred_at.desc())
            .all()
        )

    def list_conversations_for_user(self, user_id: str) -> list[ConversationLog]:
        return (
            self.db.query(ConversationLog)
            .join(UnitAgent, UnitAgent.unit_id == ConversationLog.unit_id)
            .filter(UnitAgent.user_id == user_id)
            .order_by(ConversationLog.occurred_at.desc())
            .all()
        )

    def create_conversation(self, **kwargs) -> ConversationLog:
        obj = ConversationLog(**kwargs)
        self.db.add(obj)
        self.db.commit()
        self.db.refresh(obj)
        return obj

    # ── Briefs ─────────────────────────────────────────────────────────────────

    def _last_briefed_subquery(self):
        """Correlated subquery: max last_briefed_date across a brief's linked units."""
        return (
            select(func.max(ReserveUnit.last_briefed_date))
            .where(BriefUnit.unit_id == ReserveUnit.id)
            .where(BriefUnit.brief_id == Brief.id)
            .correlate(Brief)
            .scalar_subquery()
        )

    def _attach_last_briefed(self, rows: list) -> list[Brief]:
        results = []
        for brief, last_briefed in rows:
            dt = last_briefed.date() if last_briefed else None
            brief.last_briefed_date = dt
            results.append(brief)
        return results

    def list_briefs(self) -> list[Brief]:
        rows = (
            self.db.query(Brief, self._last_briefed_subquery().label("lb"))
            .order_by(Brief.brief_date.desc())
            .all()
        )
        return self._attach_last_briefed(rows)

    def list_briefs_for_user(self, user_id: str) -> list[Brief]:
        rows = (
            self.db.query(Brief, self._last_briefed_subquery().label("lb"))
            .join(BriefUnit, BriefUnit.brief_id == Brief.id)
            .join(UnitAgent, UnitAgent.unit_id == BriefUnit.unit_id)
            .filter(UnitAgent.user_id == user_id)
            .distinct()
            .order_by(Brief.brief_date.desc())
            .all()
        )
        return self._attach_last_briefed(rows)

    def get_brief(self, brief_id: str) -> Brief | None:
        return self.db.query(Brief).filter(Brief.id == brief_id).first()

    def create_brief(self, unit_ids: list[str], contact_ids: list[str], **kwargs) -> Brief:
        obj = Brief(**kwargs)
        self.db.add(obj)
        self.db.flush()
        for uid in unit_ids:
            self.db.add(BriefUnit(brief_id=obj.id, unit_id=uid))
        for cid in contact_ids:
            self.db.add(BriefContact(brief_id=obj.id, contact_id=cid))
        self.db.commit()
        self.db.refresh(obj)
        return obj

    def update_brief(self, brief_id: str, **kwargs) -> Brief | None:
        obj = self.get_brief(brief_id)
        if not obj:
            return None
        for k, v in kwargs.items():
            setattr(obj, k, v)
        self.db.commit()
        self.db.refresh(obj)
        return obj

    # ── Trips ──────────────────────────────────────────────────────────────────

    def list_trips(self) -> list[Trip]:
        return self.db.query(Trip).order_by(Trip.start_date.desc()).all()

    def list_trips_for_agent(self, agent_id: str) -> list[Trip]:
        return (
            self.db.query(Trip)
            .filter(Trip.agent_id == agent_id)
            .order_by(Trip.start_date.desc())
            .all()
        )

    def get_trip(self, trip_id: str) -> Trip | None:
        return self.db.query(Trip).filter(Trip.id == trip_id).first()

    def create_trip(self, brief_ids: list[str], **kwargs) -> Trip:
        obj = Trip(**kwargs)
        self.db.add(obj)
        self.db.flush()
        for bid in brief_ids:
            self.db.add(TripBrief(trip_id=obj.id, brief_id=bid))
            # also update the brief's trip_id FK for fast lookups
            self.db.query(Brief).filter(Brief.id == bid).update({"trip_id": obj.id})
        self.db.commit()
        self.db.refresh(obj)
        return obj

    def update_trip(self, trip_id: str, **kwargs) -> Trip | None:
        obj = self.get_trip(trip_id)
        if not obj:
            return None
        for k, v in kwargs.items():
            setattr(obj, k, v)
        self.db.commit()
        self.db.refresh(obj)
        return obj

    def add_brief_to_trip(self, trip_id: str, brief_id: str) -> bool:
        existing = (
            self.db.query(TripBrief)
            .filter(TripBrief.trip_id == trip_id, TripBrief.brief_id == brief_id)
            .first()
        )
        if existing:
            return False
        self.db.add(TripBrief(trip_id=trip_id, brief_id=brief_id))
        self.db.query(Brief).filter(Brief.id == brief_id).update({"trip_id": trip_id})
        self.db.commit()
        return True

    def remove_brief_from_trip(self, trip_id: str, brief_id: str) -> bool:
        row = (
            self.db.query(TripBrief)
            .filter(TripBrief.trip_id == trip_id, TripBrief.brief_id == brief_id)
            .first()
        )
        if not row:
            return False
        self.db.delete(row)
        self.db.query(Brief).filter(Brief.id == brief_id).update({"trip_id": None})
        self.db.commit()
        return True

    def list_briefs_for_trip(self, trip_id: str) -> list[Brief]:
        return (
            self.db.query(Brief)
            .join(TripBrief, TripBrief.brief_id == Brief.id)
            .filter(TripBrief.trip_id == trip_id)
            .all()
        )

    # ── Nearby-unit suggestions ────────────────────────────────────────────────

    @staticmethod
    def _haversine_miles(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        """Great-circle distance between two lat/lon points in miles."""
        R = 3958.8  # Earth radius in miles
        phi1, phi2 = math.radians(lat1), math.radians(lat2)
        dphi = math.radians(lat2 - lat1)
        dlambda = math.radians(lon2 - lon1)
        a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
        return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

    def find_nearby_units(
        self,
        lat: float,
        lon: float,
        radius_miles: float,
        start_date: date | None = None,
        end_date: date | None = None,
        exclude_unit_ids: list[str] | None = None,
    ) -> list[dict]:
        """
        Return units within radius_miles of (lat, lon), sorted by distance.
        Each result dict includes unit info, distance, and scheduling signals.
        """
        bases = (
            self.db.query(BaseLocation)
            .filter(BaseLocation.latitude.isnot(None), BaseLocation.longitude.isnot(None))
            .all()
        )
        results: list[dict] = []
        exclude = set(exclude_unit_ids or [])

        for base in bases:
            dist = self._haversine_miles(lat, lon, base.latitude, base.longitude)
            if dist > radius_miles:
                continue
            for unit in base.units:
                if unit.id in exclude:
                    continue
                # Check for an existing brief in the date window
                has_brief = False
                if start_date and end_date:
                    has_brief = (
                        self.db.query(Brief)
                        .join(BriefUnit, BriefUnit.brief_id == Brief.id)
                        .filter(
                            BriefUnit.unit_id == unit.id,
                            Brief.brief_date >= start_date,
                            Brief.brief_date <= end_date,
                        )
                        .first()
                        is not None
                    )
                results.append(
                    {
                        "unit_id": unit.id,
                        "unit_name": unit.name,
                        "base_id": base.id,
                        "base_name": base.name,
                        "base_city": base.address_city,
                        "base_state": base.state,
                        "latitude": base.latitude,
                        "longitude": base.longitude,
                        "distance_miles": round(dist, 1),
                        "crm_status": unit.crm_status.value,
                        "last_briefed_date": unit.last_briefed_date,
                        "has_scheduled_brief": has_brief,
                    }
                )

        results.sort(key=lambda r: r["distance_miles"])
        return results
