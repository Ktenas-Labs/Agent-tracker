from datetime import datetime
from pydantic import BaseModel, ConfigDict, Field


class RegionIn(BaseModel):
    name: str = Field(min_length=2, max_length=100)
    notes: str | None = Field(default=None, max_length=2000)


class RegionOut(RegionIn):
    id: str
    states: list[str] = []
    model_config = ConfigDict(from_attributes=True)


class BaseIn(BaseModel):
    region_id: str
    name: str = Field(min_length=2, max_length=150)
    state: str | None = Field(default=None, max_length=100)
    address: str | None = Field(default=None, max_length=300)
    latitude: float | None = None
    longitude: float | None = None
    notes: str | None = Field(default=None, max_length=2000)


class BaseOut(BaseIn):
    id: str
    model_config = ConfigDict(from_attributes=True)


class UnitIn(BaseModel):
    base_id: str
    name: str = Field(min_length=2, max_length=150)
    unit_type: str | None = Field(default=None, max_length=80)
    estimated_personnel_size: int | None = None
    status: str = "uncontacted"
    next_follow_up_date: datetime | None = None
    notes: str | None = Field(default=None, max_length=4000)


class UnitOut(UnitIn):
    id: str
    model_config = ConfigDict(from_attributes=True)


class UnitAssignmentIn(BaseModel):
    unit_id: str = Field(min_length=8, max_length=64)
    user_id: str = Field(min_length=8, max_length=64)


class UnitAssignmentOut(UnitAssignmentIn):
    model_config = ConfigDict(from_attributes=True)


class UserOut(BaseModel):
    id: str
    email: str
    first_name: str
    last_name: str
    role: str
    model_config = ConfigDict(from_attributes=True)


class UserStateAssignmentIn(BaseModel):
    user_id: str = Field(min_length=8, max_length=64)
    state: str = Field(min_length=2, max_length=100)


class UserStateAssignmentOut(UserStateAssignmentIn):
    model_config = ConfigDict(from_attributes=True)
