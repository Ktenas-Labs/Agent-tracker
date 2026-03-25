"""add state to bases and create user_state_assignments

Revision ID: 20260325_0005
Revises: 20260325_0004
Create Date: 2026-03-25
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20260325_0005"
down_revision: Union[str, None] = "20260325_0004"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("bases", sa.Column("state", sa.String(), nullable=True))
    op.create_index("ix_bases_state", "bases", ["state"])

    op.create_table(
        "user_state_assignments",
        sa.Column("user_id", sa.String(), sa.ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("state", sa.String(), primary_key=True),
    )


def downgrade() -> None:
    op.drop_table("user_state_assignments")
    op.drop_index("ix_bases_state", table_name="bases")
    op.drop_column("bases", "state")
