"""add states column and seed regions

Revision ID: 20260325_0004
Revises: 20260324_0003
Create Date: 2026-03-25
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import ARRAY


revision: str = "20260325_0004"
down_revision: Union[str, None] = "20260324_0003"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

REGIONS = [
    {
        "id": "63rd",
        "name": "63rd Readiness Division",
        "states": [
            "California", "Nevada", "Arizona", "New Mexico",
            "Texas", "Oklahoma", "Arkansas",
        ],
        "notes": "West Coast",
    },
    {
        "id": "81st",
        "name": "81st Readiness Division",
        "states": [
            "Louisiana", "Mississippi", "Alabama", "Georgia", "Florida",
            "Tennessee", "Kentucky", "North Carolina", "South Carolina",
        ],
        "notes": "Southeast",
    },
    {
        "id": "88th",
        "name": "88th Readiness Division",
        "states": [
            "Washington", "Oregon", "Idaho", "Montana", "Wyoming",
            "Utah", "Colorado", "North Dakota", "South Dakota",
            "Nebraska", "Kansas", "Missouri", "Iowa", "Minnesota",
            "Wisconsin", "Illinois", "Indiana", "Michigan", "Ohio",
        ],
        "notes": "Midwest and Pacific Northwest",
    },
    {
        "id": "99th",
        "name": "99th Readiness Division",
        "states": [
            "Virginia", "West Virginia", "Maryland", "Delaware",
            "New Jersey", "Pennsylvania", "New York", "Connecticut",
            "Rhode Island", "Massachusetts", "Vermont", "New Hampshire",
            "Maine", "D.C.",
        ],
        "notes": "Northeast",
    },
]


def upgrade() -> None:
    op.add_column(
        "regions",
        sa.Column(
            "states",
            ARRAY(sa.String()),
            nullable=False,
            server_default="{}",
        ),
    )

    regions_table = sa.table(
        "regions",
        sa.column("id", sa.String()),
        sa.column("name", sa.String()),
        sa.column("states", ARRAY(sa.String())),
        sa.column("notes", sa.Text()),
    )
    op.bulk_insert(regions_table, REGIONS)


def downgrade() -> None:
    op.execute("DELETE FROM regions WHERE id IN ('63rd', '81st', '88th', '99th')")
    op.drop_column("regions", "states")
