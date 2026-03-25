import enum
import uuid
from datetime import datetime, date, time

from sqlalchemy import (
    String, Boolean, Date, Time, DateTime, Enum, ForeignKey,
    Text, Integer, Float,
)
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


# ── Enums ──────────────────────────────────────────────────────────────────────

class UserRole(str, enum.Enum):
    agent = "agent"
    manager = "manager"
    director = "director"


class Branch(str, enum.Enum):
    army = "army"
    air_force = "air_force"
    army_national_guard = "army_national_guard"
    air_national_guard = "air_national_guard"
    navy = "navy"
    marines = "marines"
    coast_guard = "coast_guard"
    space_force = "space_force"


class Program(str, enum.Enum):
    ssli = "ssli"
    rgli = "rgli"


class CrmStatus(str, enum.Enum):
    uncontacted = "uncontacted"
    contacted = "contacted"
    scheduling = "scheduling"
    scheduled = "scheduled"
    briefed = "briefed"
    follow_up_needed = "follow_up_needed"
    inactive = "inactive"


class BriefStatus(str, enum.Enum):
    draft = "draft"          # just created, no date confirmed yet
    outreach = "outreach"    # actively contacting unit to schedule
    scheduled = "scheduled"  # date/time confirmed with unit
    completed = "completed"  # brief conducted, actuals may be filled
    cancelled = "cancelled"
    rescheduled = "rescheduled"


class TripStatus(str, enum.Enum):
    planning = "planning"    # agent is building the itinerary
    confirmed = "confirmed"  # all briefs locked in
    completed = "completed"
    cancelled = "cancelled"


# ── Reference tables ───────────────────────────────────────────────────────────

class State(Base):
    __tablename__ = "states"
    code: Mapped[str] = mapped_column(String(2), primary_key=True)
    name: Mapped[str] = mapped_column(String, unique=True, nullable=False)


class Region(Base):
    __tablename__ = "regions"
    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    name: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    states: Mapped[list[str]] = mapped_column(ARRAY(String(2)), nullable=False, server_default="{}")
    notes: Mapped[str | None] = mapped_column(Text, default=None)

    bases: Mapped[list["BaseLocation"]] = relationship("BaseLocation", back_populates="region")


# ── Core tables ────────────────────────────────────────────────────────────────

class User(Base):
    __tablename__ = "users"
    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    email: Mapped[str] = mapped_column(String, unique=True, index=True, nullable=False)
    first_name: Mapped[str] = mapped_column(String, nullable=False)
    last_name: Mapped[str] = mapped_column(String, nullable=False)
    # Hierarchical role: agent < manager < director
    role: Mapped[UserRole] = mapped_column(Enum(UserRole), nullable=False, default=UserRole.agent)
    # Independent admin flag — orthogonal to the role hierarchy
    is_admin: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    # Contact details
    mobile_phone: Mapped[str | None] = mapped_column(String, default=None)
    office_phone: Mapped[str | None] = mapped_column(String, default=None)
    # Home address
    address_street: Mapped[str | None] = mapped_column(String, default=None)
    address_city: Mapped[str | None] = mapped_column(String, default=None)
    address_state: Mapped[str | None] = mapped_column(ForeignKey("states.code"), default=None)
    address_zip: Mapped[str | None] = mapped_column(String, default=None)
    # Program identifiers
    ssli_agent_number: Mapped[str | None] = mapped_column(String, default=None)
    rgli_agent_number: Mapped[str | None] = mapped_column(String, default=None)
    # Google Workspace OAuth — stored when user connects via /integrations/google/connect
    google_refresh_token: Mapped[str | None] = mapped_column(Text, default=None)
    google_token_scopes: Mapped[str | None] = mapped_column(String, default=None)
    google_connected_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)

    @property
    def display_name(self) -> str:
        return f"{self.first_name} {self.last_name}".strip()

    # Derived role helpers (document §7 transitivity rules)
    @property
    def is_director(self) -> bool:
        return self.role == UserRole.director

    @property
    def is_manager(self) -> bool:
        return self.role in (UserRole.manager, UserRole.director)

    @property
    def is_agent(self) -> bool:
        return True  # all users are always agents


class BaseLocation(Base):
    __tablename__ = "bases"
    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    region_id: Mapped[str] = mapped_column(ForeignKey("regions.id"), index=True, nullable=False)
    # The specific state this base is in (region spans many states)
    state: Mapped[str | None] = mapped_column(ForeignKey("states.code"), index=True, default=None)
    name: Mapped[str] = mapped_column(String, nullable=False)
    address_street: Mapped[str | None] = mapped_column(String, default=None)
    address_city: Mapped[str | None] = mapped_column(String, default=None)
    address_zip: Mapped[str | None] = mapped_column(String, default=None)
    latitude: Mapped[float | None] = mapped_column(Float, default=None)
    longitude: Mapped[float | None] = mapped_column(Float, default=None)
    notes: Mapped[str | None] = mapped_column(Text, default=None)

    region: Mapped[Region] = relationship("Region", back_populates="bases")
    units: Mapped[list["ReserveUnit"]] = relationship("ReserveUnit", back_populates="base")


class ReserveUnit(Base):
    __tablename__ = "reserve_units"
    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    base_id: Mapped[str] = mapped_column(ForeignKey("bases.id"), index=True, nullable=False)
    name: Mapped[str] = mapped_column(String, index=True, nullable=False)
    branch: Mapped[Branch | None] = mapped_column(Enum(Branch), default=None)
    program: Mapped[Program | None] = mapped_column(Enum(Program), default=None)
    building_name: Mapped[str | None] = mapped_column(String, default=None)
    phone: Mapped[str | None] = mapped_column(String, default=None)
    phone_ext: Mapped[str | None] = mapped_column(String, default=None)
    additional_phone: Mapped[str | None] = mapped_column(String, default=None)
    end_strength: Mapped[int | None] = mapped_column(Integer, default=None)
    wing_bde: Mapped[str | None] = mapped_column(String, default=None)
    group_bn: Mapped[str | None] = mapped_column(String, default=None)
    unit_type: Mapped[str | None] = mapped_column(String, default=None)
    # CRM outreach tracking (separate from auto-computed briefed status)
    crm_status: Mapped[CrmStatus] = mapped_column(Enum(CrmStatus), nullable=False, default=CrmStatus.uncontacted)
    # Denormalized cache — kept current by service layer on brief completion
    last_briefed_date: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)
    next_follow_up_date: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)
    last_contacted_date: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)
    notes: Mapped[str | None] = mapped_column(Text, default=None)

    base: Mapped[BaseLocation] = relationship("BaseLocation", back_populates="units")


class Contact(Base):
    __tablename__ = "contacts"
    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    first_name: Mapped[str] = mapped_column(String, nullable=False)
    last_name: Mapped[str] = mapped_column(String, index=True, nullable=False)
    rank_title: Mapped[str | None] = mapped_column(String, default=None)
    email: Mapped[str | None] = mapped_column(String, default=None)
    office_phone: Mapped[str | None] = mapped_column(String, default=None)
    work_cell: Mapped[str | None] = mapped_column(String, default=None)
    personal_cell: Mapped[str | None] = mapped_column(String, default=None)
    other_phone: Mapped[str | None] = mapped_column(String, default=None)
    notes: Mapped[str | None] = mapped_column(Text, default=None)
    # Alt address — used when contact has no unit, or has a distinct personal address
    alt_address_street: Mapped[str | None] = mapped_column(String, default=None)
    alt_address_city: Mapped[str | None] = mapped_column(String, default=None)
    alt_address_state: Mapped[str | None] = mapped_column(ForeignKey("states.code"), default=None)
    alt_address_zip: Mapped[str | None] = mapped_column(String, default=None)

    @property
    def display_name(self) -> str:
        parts = [self.rank_title, self.first_name, self.last_name]
        return " ".join(p for p in parts if p).strip()


class Brief(Base):
    __tablename__ = "briefs"
    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    assigned_agent_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    brief_title: Mapped[str | None] = mapped_column(String, default=None)
    # Planned date — nullable because drafts/outreach briefs have no confirmed date
    brief_date: Mapped[date | None] = mapped_column(Date, nullable=True, default=None)
    start_time: Mapped[time | None] = mapped_column(Time, default=None)
    status: Mapped[BriefStatus] = mapped_column(Enum(BriefStatus), nullable=False, default=BriefStatus.draft)
    # Alt address — when briefing is at a location other than the unit's base
    alt_address_street: Mapped[str | None] = mapped_column(String, default=None)
    alt_address_city: Mapped[str | None] = mapped_column(String, default=None)
    alt_address_state: Mapped[str | None] = mapped_column(ForeignKey("states.code"), default=None)
    alt_address_zip: Mapped[str | None] = mapped_column(String, default=None)
    confirmation_obtained: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    expected_pax: Mapped[int | None] = mapped_column(Integer, default=None)
    # apps_submitted: recorded day-of; final_apps may be lower due to withdrawals
    num_apps_obtained: Mapped[int | None] = mapped_column(Integer, default=None)
    final_apps: Mapped[int | None] = mapped_column(Integer, default=None)
    # Actuals — filled in after the brief is conducted
    actual_date: Mapped[date | None] = mapped_column(Date, default=None)
    actual_start_time: Mapped[time | None] = mapped_column(Time, default=None)
    actual_attendance: Mapped[int | None] = mapped_column(Integer, default=None)
    # Trip this brief belongs to (optional — briefs outside any trip are fine)
    trip_id: Mapped[str | None] = mapped_column(ForeignKey("trips.id"), index=True, default=None)
    notes: Mapped[str | None] = mapped_column(Text, default=None)

    trip: Mapped["Trip | None"] = relationship(
        "Trip",
        foreign_keys="[Brief.trip_id]",
        back_populates="briefs",
    )


class ConversationLog(Base):
    __tablename__ = "conversation_logs"
    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    unit_id: Mapped[str] = mapped_column(ForeignKey("reserve_units.id"), index=True, nullable=False)
    agent_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    # Optional — contact may not yet be in the system
    contact_id: Mapped[str | None] = mapped_column(ForeignKey("contacts.id"), default=None)
    # Optional — links this outreach record to a specific brief being coordinated
    brief_id: Mapped[str | None] = mapped_column(ForeignKey("briefs.id"), index=True, default=None)
    contact_person: Mapped[str] = mapped_column(String, nullable=False)
    contact_role: Mapped[str | None] = mapped_column(String, default=None)
    channel: Mapped[str] = mapped_column(String, nullable=False)
    summary: Mapped[str] = mapped_column(Text, nullable=False)
    next_step: Mapped[str | None] = mapped_column(Text, default=None)
    follow_up_due_date: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)


# ── Junction tables ────────────────────────────────────────────────────────────

class ContactUnit(Base):
    """M:M — contacts ↔ reserve_units"""
    __tablename__ = "contact_units"
    contact_id: Mapped[str] = mapped_column(ForeignKey("contacts.id", ondelete="CASCADE"), primary_key=True)
    unit_id: Mapped[str] = mapped_column(ForeignKey("reserve_units.id", ondelete="CASCADE"), primary_key=True)


class BriefUnit(Base):
    """M:M — briefs ↔ reserve_units (a briefing can cover multiple units)"""
    __tablename__ = "brief_units"
    brief_id: Mapped[str] = mapped_column(ForeignKey("briefs.id", ondelete="CASCADE"), primary_key=True)
    unit_id: Mapped[str] = mapped_column(ForeignKey("reserve_units.id", ondelete="CASCADE"), primary_key=True)


class BriefContact(Base):
    """M:M — briefs ↔ contacts (permanent attendance record)"""
    __tablename__ = "brief_contacts"
    brief_id: Mapped[str] = mapped_column(ForeignKey("briefs.id", ondelete="CASCADE"), primary_key=True)
    contact_id: Mapped[str] = mapped_column(ForeignKey("contacts.id", ondelete="CASCADE"), primary_key=True)


class UnitAgent(Base):
    """M:M — reserve_units ↔ users (agent assignments)"""
    __tablename__ = "unit_agents"
    unit_id: Mapped[str] = mapped_column(ForeignKey("reserve_units.id", ondelete="CASCADE"), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)


class UnitManager(Base):
    """M:M — reserve_units ↔ users (manager oversight; intentionally separate from UnitAgent)"""
    __tablename__ = "unit_managers"
    unit_id: Mapped[str] = mapped_column(ForeignKey("reserve_units.id", ondelete="CASCADE"), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)


class UserStateLicense(Base):
    """M:M — users ↔ states (per-state agent licensing)"""
    __tablename__ = "user_state_licenses"
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    state_code: Mapped[str] = mapped_column(ForeignKey("states.code", ondelete="CASCADE"), primary_key=True)


# ── Trip planning ───────────────────────────────────────────────────────────────

class Trip(Base):
    """Agent-owned multi-brief weekend/travel plan."""
    __tablename__ = "trips"
    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    agent_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    name: Mapped[str] = mapped_column(String, nullable=False)
    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    end_date: Mapped[date] = mapped_column(Date, nullable=False)
    status: Mapped[TripStatus] = mapped_column(Enum(TripStatus), nullable=False, default=TripStatus.planning)
    notes: Mapped[str | None] = mapped_column(Text, default=None)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)

    briefs: Mapped[list["Brief"]] = relationship("Brief", back_populates="trip")


class TripBrief(Base):
    """Explicit junction so trip-brief membership can be queried directly."""
    __tablename__ = "trip_briefs"
    trip_id: Mapped[str] = mapped_column(ForeignKey("trips.id", ondelete="CASCADE"), primary_key=True)
    brief_id: Mapped[str] = mapped_column(ForeignKey("briefs.id", ondelete="CASCADE"), primary_key=True)
