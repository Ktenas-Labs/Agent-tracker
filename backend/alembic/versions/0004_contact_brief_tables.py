"""contacts, briefs, and conversation_logs tables

contacts: military personnel agents build relationships with.
  - Full name split, rank/title, four phone fields, notes, optional alt address.
  - Unit associations handled via contact_units junction (migration 0005).

briefs: scheduled or completed briefing events.
  - Owned by one agent; linked to one or more units via brief_units junction.
  - Uses structured date + time fields. Alt address for off-site events.
  - Unit associations (and thus base/region) are via brief_units junction.

conversation_logs: CRM outreach records (agent ↔ unit).
  - Optional FK to a known contact for richer history.

Revision ID: 0004
Revises: 0003
Create Date: 2026-03-25
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0004"
down_revision: Union[str, None] = "0003"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── Contacts ─────────────────────────────────────────────────────────────
    op.create_table(
        "contacts",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("first_name", sa.String(), nullable=False),
        sa.Column("last_name", sa.String(), nullable=False),
        sa.Column("rank_title", sa.String(), nullable=True),
        sa.Column("email", sa.String(), nullable=True),
        # Four phone fields — military contacts have many numbers
        sa.Column("office_phone", sa.String(), nullable=True),
        sa.Column("work_cell", sa.String(), nullable=True),
        sa.Column("personal_cell", sa.String(), nullable=True),
        sa.Column("other_phone", sa.String(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        # Alt address — used when contact has no unit or a distinct personal address
        sa.Column("alt_address_street", sa.String(), nullable=True),
        sa.Column("alt_address_city", sa.String(), nullable=True),
        sa.Column("alt_address_state", sa.String(2), sa.ForeignKey("states.code"), nullable=True),
        sa.Column("alt_address_zip", sa.String(), nullable=True),
    )
    op.create_index("ix_contacts_last_name", "contacts", ["last_name"])

    # ── Briefs ───────────────────────────────────────────────────────────────
    op.create_table(
        "briefs",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("assigned_agent_id", sa.String(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("brief_title", sa.String(), nullable=True),
        sa.Column("brief_date", sa.Date(), nullable=False),
        sa.Column("start_time", sa.Time(), nullable=True),
        sa.Column(
            "status",
            sa.Enum("scheduled", "completed", "cancelled", "rescheduled", name="briefstatus"),
            nullable=False,
            server_default="scheduled",
        ),
        # Alt address — when briefing is at a location other than the unit's base
        sa.Column("alt_address_street", sa.String(), nullable=True),
        sa.Column("alt_address_city", sa.String(), nullable=True),
        sa.Column("alt_address_state", sa.String(2), sa.ForeignKey("states.code"), nullable=True),
        sa.Column("alt_address_zip", sa.String(), nullable=True),
        sa.Column("confirmation_obtained", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("expected_pax", sa.Integer(), nullable=True),
        sa.Column("num_apps_obtained", sa.Integer(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
    )
    op.create_index("ix_briefs_assigned_agent_id", "briefs", ["assigned_agent_id"])
    op.create_index("ix_briefs_brief_date", "briefs", ["brief_date"])
    op.create_index("ix_briefs_status", "briefs", ["status"])

    # ── Conversation Logs ────────────────────────────────────────────────────
    op.create_table(
        "conversation_logs",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("unit_id", sa.String(), sa.ForeignKey("reserve_units.id"), nullable=False),
        sa.Column("agent_id", sa.String(), sa.ForeignKey("users.id"), nullable=False),
        # Optional FK — contact may not yet be in the system
        sa.Column("contact_id", sa.String(), sa.ForeignKey("contacts.id"), nullable=True),
        sa.Column("contact_person", sa.String(), nullable=False),
        sa.Column("contact_role", sa.String(), nullable=True),
        sa.Column("channel", sa.String(), nullable=False),
        sa.Column("summary", sa.Text(), nullable=False),
        sa.Column("next_step", sa.Text(), nullable=True),
        sa.Column("follow_up_due_date", sa.DateTime(timezone=True), nullable=True),
        sa.Column("occurred_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_conversation_logs_unit_id", "conversation_logs", ["unit_id"])
    op.create_index("ix_conversation_logs_agent_id", "conversation_logs", ["agent_id"])


def downgrade() -> None:
    op.drop_index("ix_conversation_logs_agent_id", table_name="conversation_logs")
    op.drop_index("ix_conversation_logs_unit_id", table_name="conversation_logs")
    op.drop_table("conversation_logs")
    op.drop_index("ix_briefs_status", table_name="briefs")
    op.drop_index("ix_briefs_brief_date", table_name="briefs")
    op.drop_index("ix_briefs_assigned_agent_id", table_name="briefs")
    op.drop_table("briefs")
    op.execute("DROP TYPE IF EXISTS briefstatus")
    op.drop_index("ix_contacts_last_name", table_name="contacts")
    op.drop_table("contacts")
