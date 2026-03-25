"""reference tables: states (seeded) and regions (seeded)

Revision ID: 0001
Revises: None
Create Date: 2026-03-25
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import ARRAY


revision: str = "0001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


# All 50 US states + District of Columbia
_STATES: list[tuple[str, str]] = [
    ("AL", "Alabama"), ("AK", "Alaska"), ("AZ", "Arizona"), ("AR", "Arkansas"),
    ("CA", "California"), ("CO", "Colorado"), ("CT", "Connecticut"), ("DC", "District of Columbia"),
    ("DE", "Delaware"), ("FL", "Florida"), ("GA", "Georgia"), ("HI", "Hawaii"),
    ("ID", "Idaho"), ("IL", "Illinois"), ("IN", "Indiana"), ("IA", "Iowa"),
    ("KS", "Kansas"), ("KY", "Kentucky"), ("LA", "Louisiana"), ("ME", "Maine"),
    ("MD", "Maryland"), ("MA", "Massachusetts"), ("MI", "Michigan"), ("MN", "Minnesota"),
    ("MS", "Mississippi"), ("MO", "Missouri"), ("MT", "Montana"), ("NE", "Nebraska"),
    ("NV", "Nevada"), ("NH", "New Hampshire"), ("NJ", "New Jersey"), ("NM", "New Mexico"),
    ("NY", "New York"), ("NC", "North Carolina"), ("ND", "North Dakota"), ("OH", "Ohio"),
    ("OK", "Oklahoma"), ("OR", "Oregon"), ("PA", "Pennsylvania"), ("RI", "Rhode Island"),
    ("SC", "South Carolina"), ("SD", "South Dakota"), ("TN", "Tennessee"), ("TX", "Texas"),
    ("UT", "Utah"), ("VT", "Vermont"), ("VA", "Virginia"), ("WA", "Washington"),
    ("WV", "West Virginia"), ("WI", "Wisconsin"), ("WY", "Wyoming"),
]

# Army Readiness Divisions — static, never change
_REGIONS = [
    {
        "id": "63rd",
        "name": "63rd Readiness Division",
        "states": ["CA", "NV", "AZ", "NM", "TX", "OK", "AR"],
        "notes": "West Coast",
    },
    {
        "id": "81st",
        "name": "81st Readiness Division",
        "states": ["LA", "MS", "AL", "GA", "FL", "TN", "KY", "NC", "SC"],
        "notes": "Southeast",
    },
    {
        "id": "88th",
        "name": "88th Readiness Division",
        "states": ["WA", "OR", "ID", "MT", "WY", "UT", "CO", "ND", "SD",
                   "NE", "KS", "MO", "IA", "MN", "WI", "IL", "IN", "MI", "OH"],
        "notes": "Midwest and Pacific Northwest",
    },
    {
        "id": "99th",
        "name": "99th Readiness Division",
        "states": ["VA", "WV", "MD", "DE", "NJ", "PA", "NY", "CT",
                   "RI", "MA", "VT", "NH", "ME", "DC"],
        "notes": "Northeast",
    },
]


def upgrade() -> None:
    # ── States reference table ──────────────────────────────────────────────
    op.create_table(
        "states",
        sa.Column("code", sa.String(2), primary_key=True),
        sa.Column("name", sa.String(), nullable=False, unique=True),
    )
    states_tbl = sa.table("states", sa.column("code", sa.String(2)), sa.column("name", sa.String()))
    op.bulk_insert(states_tbl, [{"code": c, "name": n} for c, n in _STATES])

    # ── Regions (Readiness Divisions) ───────────────────────────────────────
    op.create_table(
        "regions",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("name", sa.String(), nullable=False, unique=True),
        sa.Column("states", ARRAY(sa.String(2)), nullable=False, server_default="{}"),
        sa.Column("notes", sa.Text(), nullable=True),
    )
    regions_tbl = sa.table(
        "regions",
        sa.column("id", sa.String()),
        sa.column("name", sa.String()),
        sa.column("states", ARRAY(sa.String(2))),
        sa.column("notes", sa.Text()),
    )
    op.bulk_insert(regions_tbl, _REGIONS)


def downgrade() -> None:
    op.drop_table("regions")
    op.drop_table("states")
