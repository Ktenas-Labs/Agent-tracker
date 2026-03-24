"""initial schema

Revision ID: 20260324_0001
Revises: None
Create Date: 2026-03-24
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20260324_0001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("email", sa.String(), nullable=False, unique=True),
        sa.Column("first_name", sa.String(), nullable=False),
        sa.Column("last_name", sa.String(), nullable=False),
        sa.Column("role", sa.Enum("admin", "manager", "agent", name="userrole"), nullable=False),
    )
    op.create_table(
        "regions",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("name", sa.String(), nullable=False, unique=True),
        sa.Column("notes", sa.Text(), nullable=True),
    )
    op.create_table(
        "bases",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("region_id", sa.String(), sa.ForeignKey("regions.id"), nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("address", sa.String(), nullable=True),
        sa.Column("latitude", sa.Float(), nullable=True),
        sa.Column("longitude", sa.Float(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
    )
    op.create_table(
        "reserve_units",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("base_id", sa.String(), sa.ForeignKey("bases.id"), nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("unit_type", sa.String(), nullable=True),
        sa.Column("estimated_personnel_size", sa.Integer(), nullable=True),
        sa.Column(
            "status",
            sa.Enum(
                "uncontacted",
                "contacted",
                "scheduling",
                "scheduled",
                "briefed",
                "follow_up_needed",
                "inactive",
                name="unitstatus",
            ),
            nullable=False,
        ),
        sa.Column("next_follow_up_date", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_contacted_date", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_briefed_date", sa.DateTime(timezone=True), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
    )


def downgrade() -> None:
    op.drop_table("reserve_units")
    op.drop_table("bases")
    op.drop_table("regions")
    op.drop_table("users")
    op.execute("DROP TYPE IF EXISTS unitstatus")
    op.execute("DROP TYPE IF EXISTS userrole")
