"""contacts, conversation_logs, briefs

Revision ID: 20260324_0003
Revises: 20260324_0002
Create Date: 2026-03-24
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20260324_0003"
down_revision: Union[str, None] = "20260324_0002"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    briefstatus = sa.Enum("scheduled", "completed", "canceled", "rescheduled", name="briefstatus")

    op.create_table(
        "contacts",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("reserve_unit_id", sa.String(), sa.ForeignKey("reserve_units.id"), nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("role", sa.String(), nullable=True),
        sa.Column("phone", sa.String(), nullable=True),
        sa.Column("email", sa.String(), nullable=True),
    )
    op.create_index("ix_contacts_reserve_unit_id", "contacts", ["reserve_unit_id"])

    op.create_table(
        "conversation_logs",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("reserve_unit_id", sa.String(), sa.ForeignKey("reserve_units.id"), nullable=False),
        sa.Column("agent_id", sa.String(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("contact_person", sa.String(), nullable=False),
        sa.Column("contact_role", sa.String(), nullable=True),
        sa.Column("channel", sa.String(), nullable=False),
        sa.Column("summary", sa.Text(), nullable=False),
        sa.Column("next_step", sa.Text(), nullable=True),
        sa.Column("follow_up_due_date", sa.DateTime(timezone=True), nullable=True),
        sa.Column("occurred_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_conversation_logs_reserve_unit_id", "conversation_logs", ["reserve_unit_id"])
    op.create_index("ix_conversation_logs_agent_id", "conversation_logs", ["agent_id"])

    op.create_table(
        "briefs",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("reserve_unit_id", sa.String(), sa.ForeignKey("reserve_units.id"), nullable=False),
        sa.Column("base_id", sa.String(), sa.ForeignKey("bases.id"), nullable=False),
        sa.Column("region_id", sa.String(), sa.ForeignKey("regions.id"), nullable=False),
        sa.Column("assigned_agent_id", sa.String(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("scheduled_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("status", briefstatus, nullable=False),
        sa.Column("location", sa.String(), nullable=True),
        sa.Column("attendance_count", sa.Integer(), nullable=True),
        sa.Column("estimated_eligible_lives_reached", sa.Integer(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
    )
    op.create_index("ix_briefs_reserve_unit_id", "briefs", ["reserve_unit_id"])
    op.create_index("ix_briefs_assigned_agent_id", "briefs", ["assigned_agent_id"])


def downgrade() -> None:
    op.drop_index("ix_briefs_assigned_agent_id", table_name="briefs")
    op.drop_index("ix_briefs_reserve_unit_id", table_name="briefs")
    op.drop_table("briefs")
    op.drop_index("ix_conversation_logs_agent_id", table_name="conversation_logs")
    op.drop_index("ix_conversation_logs_reserve_unit_id", table_name="conversation_logs")
    op.drop_table("conversation_logs")
    op.drop_index("ix_contacts_reserve_unit_id", table_name="contacts")
    op.drop_table("contacts")
    op.execute("DROP TYPE IF EXISTS briefstatus")
