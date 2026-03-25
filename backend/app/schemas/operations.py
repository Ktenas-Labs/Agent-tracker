from datetime import datetime, date, time
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


# ── Contacts ───────────────────────────────────────────────────────────────────

class ContactIn(BaseModel):
    first_name: str = Field(min_length=1, max_length=80)
    last_name: str = Field(min_length=1, max_length=80)
    rank_title: str | None = Field(default=None, max_length=60)
    email: str | None = Field(default=None, max_length=254)
    office_phone: str | None = Field(default=None, max_length=30)
    work_cell: str | None = Field(default=None, max_length=30)
    personal_cell: str | None = Field(default=None, max_length=30)
    other_phone: str | None = Field(default=None, max_length=30)
    notes: str | None = Field(default=None, max_length=4000)
    alt_address_street: str | None = Field(default=None, max_length=200)
    alt_address_city: str | None = Field(default=None, max_length=100)
    alt_address_state: str | None = Field(default=None, max_length=2)
    alt_address_zip: str | None = Field(default=None, max_length=20)
    # Optional: link to one or more units on creation
    unit_ids: list[str] = Field(default_factory=list)


class ContactOut(BaseModel):
    id: str
    first_name: str
    last_name: str
    rank_title: str | None = None
    email: str | None = None
    office_phone: str | None = None
    work_cell: str | None = None
    personal_cell: str | None = None
    other_phone: str | None = None
    notes: str | None = None
    alt_address_street: str | None = None
    alt_address_city: str | None = None
    alt_address_state: str | None = None
    alt_address_zip: str | None = None
    model_config = ConfigDict(from_attributes=True)


# ── Conversation Logs ──────────────────────────────────────────────────────────

class ConversationIn(BaseModel):
    unit_id: str
    agent_id: str
    contact_id: str | None = None
    # Optional: link this outreach log to the specific brief being coordinated
    brief_id: str | None = None
    contact_person: str = Field(min_length=2, max_length=120)
    contact_role: str | None = Field(default=None, max_length=80)
    channel: str = Field(min_length=2, max_length=30)
    summary: str = Field(min_length=3, max_length=4000)
    next_step: str | None = Field(default=None, max_length=1000)
    follow_up_due_date: datetime | None = None


class ConversationOut(ConversationIn):
    id: str
    occurred_at: datetime
    model_config = ConfigDict(from_attributes=True)


# ── Briefs ─────────────────────────────────────────────────────────────────────

class BriefIn(BaseModel):
    assigned_agent_id: str
    brief_title: str | None = Field(default=None, max_length=200)
    # Nullable — draft/outreach briefs don't have a confirmed date
    brief_date: date | None = None
    start_time: time | None = None
    status: str = "draft"
    trip_id: str | None = None
    # Planned location (when off-site)
    alt_address_street: str | None = Field(default=None, max_length=200)
    alt_address_city: str | None = Field(default=None, max_length=100)
    alt_address_state: str | None = Field(default=None, max_length=2)
    alt_address_zip: str | None = Field(default=None, max_length=20)
    confirmation_obtained: bool = False
    expected_pax: int | None = None
    # apps_submitted: recorded day-of
    num_apps_obtained: int | None = None
    # final_apps: after any withdrawal period
    final_apps: int | None = None
    # Actuals — recorded after brief is conducted
    actual_date: date | None = None
    actual_start_time: time | None = None
    actual_attendance: int | None = None
    notes: str | None = Field(default=None, max_length=4000)
    # Units this briefing covers
    unit_ids: list[str] = Field(default_factory=list)
    # Contacts attending this briefing
    contact_ids: list[str] = Field(default_factory=list)


class BriefOut(BaseModel):
    id: str
    assigned_agent_id: str
    brief_title: str | None = None
    brief_date: date | None = None
    start_time: time | None = None
    status: str
    trip_id: str | None = None
    alt_address_street: str | None = None
    alt_address_city: str | None = None
    alt_address_state: str | None = None
    alt_address_zip: str | None = None
    confirmation_obtained: bool
    expected_pax: int | None = None
    num_apps_obtained: int | None = None
    final_apps: int | None = None
    actual_date: date | None = None
    actual_start_time: time | None = None
    actual_attendance: int | None = None
    notes: str | None = None
    last_briefed_date: date | None = None
    model_config = ConfigDict(from_attributes=True)


# ── Trips ───────────────────────────────────────────────────────────────────────

class TripIn(BaseModel):
    agent_id: str
    name: str = Field(min_length=2, max_length=200)
    start_date: date
    end_date: date
    status: str = "planning"
    notes: str | None = Field(default=None, max_length=4000)
    # Optionally attach existing briefs on creation
    brief_ids: list[str] = Field(default_factory=list)


class TripOut(BaseModel):
    id: str
    agent_id: str
    name: str
    start_date: date
    end_date: date
    status: str
    notes: str | None = None
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)


class TripBriefAssign(BaseModel):
    """Assign or remove a brief from a trip."""
    brief_id: str


# ── Nearby-unit suggestions ─────────────────────────────────────────────────────

class NearbyUnitOut(BaseModel):
    unit_id: str
    unit_name: str
    base_id: str
    base_name: str
    base_city: str | None = None
    base_state: str | None = None
    latitude: float | None = None
    longitude: float | None = None
    distance_miles: float
    crm_status: str
    last_briefed_date: datetime | None = None
    # Whether this unit already has a brief scheduled in the requested date window
    has_scheduled_brief: bool = False
