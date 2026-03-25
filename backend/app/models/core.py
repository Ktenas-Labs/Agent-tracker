import enum
import uuid
from datetime import datetime

from sqlalchemy import String, DateTime, Enum, ForeignKey, Text, Integer
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base


class UserRole(str, enum.Enum):
    admin = "admin"
    manager = "manager"
    agent = "agent"


class UnitStatus(str, enum.Enum):
    uncontacted = "uncontacted"
    contacted = "contacted"
    scheduling = "scheduling"
    scheduled = "scheduled"
    briefed = "briefed"
    follow_up_needed = "follow_up_needed"
    inactive = "inactive"


class BriefStatus(str, enum.Enum):
    scheduled = "scheduled"
    completed = "completed"
    canceled = "canceled"
    rescheduled = "rescheduled"


class User(Base):
    __tablename__ = "users"
    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    email: Mapped[str] = mapped_column(String, unique=True, index=True)
    first_name: Mapped[str] = mapped_column(String)
    last_name: Mapped[str] = mapped_column(String)
    role: Mapped[UserRole] = mapped_column(Enum(UserRole), default=UserRole.agent)


class Region(Base):
    __tablename__ = "regions"
    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    name: Mapped[str] = mapped_column(String, unique=True, index=True)
    states: Mapped[list[str]] = mapped_column(ARRAY(String), nullable=False, server_default="{}")
    notes: Mapped[str | None] = mapped_column(Text, default=None)


class BaseLocation(Base):
    __tablename__ = "bases"
    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    region_id: Mapped[str] = mapped_column(ForeignKey("regions.id"), index=True)
    name: Mapped[str] = mapped_column(String)
    state: Mapped[str | None] = mapped_column(String, default=None, index=True)
    address: Mapped[str | None] = mapped_column(String, default=None)
    latitude: Mapped[float | None] = mapped_column(default=None)
    longitude: Mapped[float | None] = mapped_column(default=None)
    notes: Mapped[str | None] = mapped_column(Text, default=None)


class ReserveUnit(Base):
    __tablename__ = "reserve_units"
    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    base_id: Mapped[str] = mapped_column(ForeignKey("bases.id"), index=True)
    name: Mapped[str] = mapped_column(String, index=True)
    unit_type: Mapped[str | None] = mapped_column(String, default=None)
    estimated_personnel_size: Mapped[int | None] = mapped_column(Integer, default=None)
    status: Mapped[UnitStatus] = mapped_column(Enum(UnitStatus), default=UnitStatus.uncontacted)
    next_follow_up_date: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)
    last_contacted_date: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)
    last_briefed_date: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)
    notes: Mapped[str | None] = mapped_column(Text, default=None)


class Contact(Base):
    __tablename__ = "contacts"
    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    reserve_unit_id: Mapped[str] = mapped_column(ForeignKey("reserve_units.id"), index=True)
    name: Mapped[str] = mapped_column(String)
    role: Mapped[str | None] = mapped_column(String, default=None)
    phone: Mapped[str | None] = mapped_column(String, default=None)
    email: Mapped[str | None] = mapped_column(String, default=None)


class ConversationLog(Base):
    __tablename__ = "conversation_logs"
    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    reserve_unit_id: Mapped[str] = mapped_column(ForeignKey("reserve_units.id"), index=True)
    agent_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    contact_person: Mapped[str] = mapped_column(String)
    contact_role: Mapped[str | None] = mapped_column(String, default=None)
    channel: Mapped[str] = mapped_column(String)
    summary: Mapped[str] = mapped_column(Text)
    next_step: Mapped[str | None] = mapped_column(Text, default=None)
    follow_up_due_date: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)


class Brief(Base):
    __tablename__ = "briefs"
    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    reserve_unit_id: Mapped[str] = mapped_column(ForeignKey("reserve_units.id"), index=True)
    base_id: Mapped[str] = mapped_column(ForeignKey("bases.id"), index=True)
    region_id: Mapped[str] = mapped_column(ForeignKey("regions.id"), index=True)
    assigned_agent_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    scheduled_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)
    status: Mapped[BriefStatus] = mapped_column(Enum(BriefStatus), default=BriefStatus.scheduled)
    location: Mapped[str | None] = mapped_column(String, default=None)
    attendance_count: Mapped[int | None] = mapped_column(Integer, default=None)
    estimated_eligible_lives_reached: Mapped[int | None] = mapped_column(Integer, default=None)
    notes: Mapped[str | None] = mapped_column(Text, default=None)


class UnitAgentAssignment(Base):
    __tablename__ = "unit_agent_assignments"
    unit_id: Mapped[str] = mapped_column(ForeignKey("reserve_units.id"), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), primary_key=True)


class UserStateAssignment(Base):
    __tablename__ = "user_state_assignments"
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), primary_key=True)
    state: Mapped[str] = mapped_column(String, primary_key=True)
