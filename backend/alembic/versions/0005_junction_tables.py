"""junction tables — all many-to-many relationships

contact_units       contacts ↔ reserve_units   (one contact → many units)
brief_units         briefs ↔ reserve_units      (one brief can span many units)
brief_contacts      briefs ↔ contacts           (attendance record)
unit_agents         reserve_units ↔ users       (agent assignments)
unit_managers       reserve_units ↔ users       (manager oversight — separate from agents)
user_state_licenses users ↔ states              (licensing per state)

Revision ID: 0005
Revises: 0004
Create Date: 2026-03-25
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0005"
down_revision: Union[str, None] = "0004"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # contacts ↔ units
    op.create_table(
        "contact_units",
        sa.Column("contact_id", sa.String(), sa.ForeignKey("contacts.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("unit_id", sa.String(), sa.ForeignKey("reserve_units.id", ondelete="CASCADE"), primary_key=True),
    )
    op.create_index("ix_contact_units_unit_id", "contact_units", ["unit_id"])

    # briefs ↔ units — a briefing can cover multiple units at once
    op.create_table(
        "brief_units",
        sa.Column("brief_id", sa.String(), sa.ForeignKey("briefs.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("unit_id", sa.String(), sa.ForeignKey("reserve_units.id", ondelete="CASCADE"), primary_key=True),
    )
    op.create_index("ix_brief_units_unit_id", "brief_units", ["unit_id"])

    # briefs ↔ contacts — permanent attendance record
    op.create_table(
        "brief_contacts",
        sa.Column("brief_id", sa.String(), sa.ForeignKey("briefs.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("contact_id", sa.String(), sa.ForeignKey("contacts.id", ondelete="CASCADE"), primary_key=True),
    )
    op.create_index("ix_brief_contacts_contact_id", "brief_contacts", ["contact_id"])

    # unit agent assignments
    op.create_table(
        "unit_agents",
        sa.Column("unit_id", sa.String(), sa.ForeignKey("reserve_units.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("user_id", sa.String(), sa.ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
    )
    op.create_index("ix_unit_agents_user_id", "unit_agents", ["user_id"])

    # unit manager assignments — intentionally separate from unit_agents
    op.create_table(
        "unit_managers",
        sa.Column("unit_id", sa.String(), sa.ForeignKey("reserve_units.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("user_id", sa.String(), sa.ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
    )
    op.create_index("ix_unit_managers_user_id", "unit_managers", ["user_id"])

    # per-agent state licensing
    op.create_table(
        "user_state_licenses",
        sa.Column("user_id", sa.String(), sa.ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("state_code", sa.String(2), sa.ForeignKey("states.code", ondelete="CASCADE"), primary_key=True),
    )
    op.create_index("ix_user_state_licenses_state_code", "user_state_licenses", ["state_code"])


def downgrade() -> None:
    op.drop_index("ix_user_state_licenses_state_code", table_name="user_state_licenses")
    op.drop_table("user_state_licenses")
    op.drop_index("ix_unit_managers_user_id", table_name="unit_managers")
    op.drop_table("unit_managers")
    op.drop_index("ix_unit_agents_user_id", table_name="unit_agents")
    op.drop_table("unit_agents")
    op.drop_index("ix_brief_contacts_contact_id", table_name="brief_contacts")
    op.drop_table("brief_contacts")
    op.drop_index("ix_brief_units_unit_id", table_name="brief_units")
    op.drop_table("brief_units")
    op.drop_index("ix_contact_units_unit_id", table_name="contact_units")
    op.drop_table("contact_units")
