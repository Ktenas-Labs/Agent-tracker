"""add trip_id FK column to briefs

0006 created the trips table and trip_briefs junction but omitted the
trip_id column on briefs itself.

Revision ID: 0007
Revises: 0006
Create Date: 2026-03-25
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0007"
down_revision: Union[str, None] = "0006"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "briefs",
        sa.Column(
            "trip_id",
            sa.String(),
            sa.ForeignKey("trips.id", ondelete="SET NULL"),
            nullable=True,
        ),
    )
    op.create_index("ix_briefs_trip_id", "briefs", ["trip_id"])


def downgrade() -> None:
    op.drop_index("ix_briefs_trip_id", table_name="briefs")
    op.drop_column("briefs", "trip_id")
