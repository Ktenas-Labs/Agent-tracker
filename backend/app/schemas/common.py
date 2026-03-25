from pydantic import BaseModel, ConfigDict, Field


# ── States ─────────────────────────────────────────────────────────────────────

class StateOut(BaseModel):
    code: str
    name: str
    model_config = ConfigDict(from_attributes=True)


# ── Regions ────────────────────────────────────────────────────────────────────

class RegionIn(BaseModel):
    name: str = Field(min_length=2, max_length=100)
    notes: str | None = Field(default=None, max_length=2000)


class RegionOut(RegionIn):
    id: str
    states: list[str] = []
    model_config = ConfigDict(from_attributes=True)


# ── Bases ──────────────────────────────────────────────────────────────────────

class BaseIn(BaseModel):
    region_id: str
    state: str | None = Field(default=None, max_length=2)
    name: str = Field(min_length=2, max_length=150)
    address_street: str | None = Field(default=None, max_length=200)
    address_city: str | None = Field(default=None, max_length=100)
    address_zip: str | None = Field(default=None, max_length=20)
    latitude: float | None = None
    longitude: float | None = None
    notes: str | None = Field(default=None, max_length=2000)


class BaseOut(BaseIn):
    id: str
    model_config = ConfigDict(from_attributes=True)


# ── Reserve Units ──────────────────────────────────────────────────────────────

class UnitIn(BaseModel):
    base_id: str
    name: str = Field(min_length=2, max_length=150)
    branch: str | None = Field(default=None)
    program: str | None = Field(default=None)
    building_name: str | None = Field(default=None, max_length=150)
    phone: str | None = Field(default=None, max_length=30)
    phone_ext: str | None = Field(default=None, max_length=10)
    additional_phone: str | None = Field(default=None, max_length=30)
    end_strength: int | None = None
    wing_bde: str | None = Field(default=None, max_length=100)
    group_bn: str | None = Field(default=None, max_length=100)
    unit_type: str | None = Field(default=None, max_length=80)
    crm_status: str = "uncontacted"
    notes: str | None = Field(default=None, max_length=4000)


class UnitOut(UnitIn):
    id: str
    model_config = ConfigDict(from_attributes=True)


# ── Unit assignments ───────────────────────────────────────────────────────────

class UnitAgentIn(BaseModel):
    unit_id: str = Field(min_length=8, max_length=64)
    user_id: str = Field(min_length=8, max_length=64)


class UnitAgentOut(UnitAgentIn):
    model_config = ConfigDict(from_attributes=True)


class UnitManagerIn(BaseModel):
    unit_id: str = Field(min_length=8, max_length=64)
    user_id: str = Field(min_length=8, max_length=64)


class UnitManagerOut(UnitManagerIn):
    model_config = ConfigDict(from_attributes=True)


# ── Regions (update) ───────────────────────────────────────────────────────────

class RegionUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=100)
    notes: str | None = Field(default=None, max_length=2000)
    states: list[str] | None = None


# ── Bases (update) ─────────────────────────────────────────────────────────────

class BaseUpdate(BaseModel):
    region_id: str | None = None
    state: str | None = Field(default=None, max_length=2)
    name: str | None = Field(default=None, min_length=2, max_length=150)
    address_street: str | None = Field(default=None, max_length=200)
    address_city: str | None = Field(default=None, max_length=100)
    address_zip: str | None = Field(default=None, max_length=20)
    latitude: float | None = None
    longitude: float | None = None
    notes: str | None = Field(default=None, max_length=2000)


# ── Users ──────────────────────────────────────────────────────────────────────

class UserOut(BaseModel):
    id: str
    email: str
    first_name: str
    last_name: str
    role: str
    is_admin: bool
    mobile_phone: str | None = None
    office_phone: str | None = None
    address_street: str | None = None
    address_city: str | None = None
    address_state: str | None = None
    address_zip: str | None = None
    ssli_agent_number: str | None = None
    rgli_agent_number: str | None = None
    model_config = ConfigDict(from_attributes=True)


class UserCreate(BaseModel):
    email: str = Field(min_length=3, max_length=254)
    first_name: str = Field(min_length=1, max_length=80)
    last_name: str = Field(min_length=1, max_length=80)
    role: str = Field(default="agent")
    is_admin: bool = False
    mobile_phone: str | None = Field(default=None, max_length=30)
    office_phone: str | None = Field(default=None, max_length=30)
    address_street: str | None = Field(default=None, max_length=200)
    address_city: str | None = Field(default=None, max_length=100)
    address_state: str | None = Field(default=None, max_length=2)
    address_zip: str | None = Field(default=None, max_length=20)
    ssli_agent_number: str | None = Field(default=None, max_length=50)
    rgli_agent_number: str | None = Field(default=None, max_length=50)


class UserUpdate(BaseModel):
    email: str | None = Field(default=None, min_length=3, max_length=254)
    first_name: str | None = Field(default=None, min_length=1, max_length=80)
    last_name: str | None = Field(default=None, min_length=1, max_length=80)
    role: str | None = None
    is_admin: bool | None = None
    mobile_phone: str | None = Field(default=None, max_length=30)
    office_phone: str | None = Field(default=None, max_length=30)
    address_street: str | None = Field(default=None, max_length=200)
    address_city: str | None = Field(default=None, max_length=100)
    address_state: str | None = Field(default=None, max_length=2)
    address_zip: str | None = Field(default=None, max_length=20)
    ssli_agent_number: str | None = Field(default=None, max_length=50)
    rgli_agent_number: str | None = Field(default=None, max_length=50)


# ── State licenses ─────────────────────────────────────────────────────────────

class UserStateLicenseIn(BaseModel):
    user_id: str = Field(min_length=8, max_length=64)
    state_code: str = Field(min_length=2, max_length=2)


class UserStateLicenseOut(UserStateLicenseIn):
    model_config = ConfigDict(from_attributes=True)


# ── Keep old alias so existing route calls still resolve ──────────────────────
UnitAssignmentIn = UnitAgentIn
UnitAssignmentOut = UnitAgentOut
UserStateAssignmentIn = UserStateLicenseIn
UserStateAssignmentOut = UserStateLicenseOut
