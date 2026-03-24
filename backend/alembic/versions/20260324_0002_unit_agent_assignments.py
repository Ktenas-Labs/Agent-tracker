"""unit agent assignments

Revision ID: 20260324_0002
Revises: 20260324_0001
Create Date: 2026-03-24
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20260324_0002"
down_revision: Union[str, None] = "20260324_0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "unit_agent_assignments",
        sa.Column("unit_id", sa.String(), sa.ForeignKey("reserve_units.id"), primary_key=True),
        sa.Column("user_id", sa.String(), sa.ForeignKey("users.id"), primary_key=True),
    )


def downgrade() -> None:
    op.drop_table("unit_agent_assignments")
