"""users table

Role hierarchy (document §4): agent < manager < director.
is_admin is an independent flag that grants system-administration access
and can be combined with any role.

Revision ID: 0002
Revises: 0001
Create Date: 2026-03-25
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0002"
down_revision: Union[str, None] = "0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("email", sa.String(), nullable=False, unique=True),
        sa.Column("first_name", sa.String(), nullable=False),
        sa.Column("last_name", sa.String(), nullable=False),
        # Hierarchical role: agent < manager < director
        sa.Column(
            "role",
            sa.Enum("agent", "manager", "director", name="userrole"),
            nullable=False,
            server_default="agent",
        ),
        # Independent admin flag — orthogonal to the role hierarchy
        sa.Column("is_admin", sa.Boolean(), nullable=False, server_default="false"),
        # Contact details
        sa.Column("mobile_phone", sa.String(), nullable=True),
        sa.Column("office_phone", sa.String(), nullable=True),
        # Home address
        sa.Column("address_street", sa.String(), nullable=True),
        sa.Column("address_city", sa.String(), nullable=True),
        sa.Column("address_state", sa.String(2), sa.ForeignKey("states.code"), nullable=True),
        sa.Column("address_zip", sa.String(), nullable=True),
        # Program identifiers
        sa.Column("ssli_agent_number", sa.String(), nullable=True),
        sa.Column("rgli_agent_number", sa.String(), nullable=True),
    )
    op.create_index("ix_users_email", "users", ["email"], unique=True)


def downgrade() -> None:
    op.drop_index("ix_users_email", table_name="users")
    op.drop_table("users")
    op.execute("DROP TYPE IF EXISTS userrole")
