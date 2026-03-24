from datetime import datetime
from pydantic import BaseModel, ConfigDict, Field


class ContactIn(BaseModel):
    reserve_unit_id: str
    name: str = Field(min_length=2, max_length=120)
    role: str | None = Field(default=None, max_length=80)
    phone: str | None = Field(default=None, max_length=30)
    email: str | None = Field(default=None, max_length=254)


class ContactOut(ContactIn):
    id: str
    model_config = ConfigDict(from_attributes=True)


class ConversationIn(BaseModel):
    reserve_unit_id: str
    agent_id: str
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


class BriefIn(BaseModel):
    reserve_unit_id: str
    base_id: str
    region_id: str
    assigned_agent_id: str
    scheduled_at: datetime
    status: str = "scheduled"
    location: str | None = Field(default=None, max_length=300)
    attendance_count: int | None = None
    estimated_eligible_lives_reached: int | None = None
    notes: str | None = Field(default=None, max_length=4000)


class BriefOut(BriefIn):
    id: str
    completed_at: datetime | None = None
    model_config = ConfigDict(from_attributes=True)
