"""brief lifecycle, actuals, trips, and scheduling comms

Changes:
  briefs:
    - brief_date becomes nullable (drafts have no confirmed date yet)
    - new status values: 'draft', 'outreach' added to briefstatus enum
    - new columns: actual_date, actual_start_time, actual_attendance, final_apps, trip_id

  conversation_logs:
    - optional brief_id FK — links scheduling calls/emails to the brief they coordinate

  new table: trips
    - agent-owned multi-brief weekend planning object
    - status: planning → confirmed → completed | cancelled

  new table: trip_briefs
    - junction linking briefs to their trip (one trip, many briefs)

Revision ID: 0006
Revises: 0005
Create Date: 2026-03-25
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy import text


revision: str = "0006"
down_revision: Union[str, None] = "0005"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── Extend briefstatus enum ──────────────────────────────────────────────
    # PostgreSQL requires ADD VALUE to run outside a transaction and be
    # committed before the new values can be used.  We drop down to the raw
    # DBAPI connection so we can toggle autocommit cleanly.
    conn = op.get_bind()
    conn.execute(text("COMMIT"))
    raw = conn.connection.dbapi_connection
    raw.autocommit = True
    raw.execute("ALTER TYPE briefstatus ADD VALUE IF NOT EXISTS 'draft'")
    raw.execute("ALTER TYPE briefstatus ADD VALUE IF NOT EXISTS 'outreach'")
    raw.autocommit = False
    conn.execute(text("BEGIN"))

    # ── Extend briefs table ──────────────────────────────────────────────────
    # Make planned date nullable — drafts don't have a confirmed date yet
    op.alter_column("briefs", "brief_date", nullable=True)

    # Change default status to 'draft' so new briefs start in draft
    op.alter_column("briefs", "status", server_default="draft")

    # Actuals — recorded after the brief is conducted
    op.add_column("briefs", sa.Column("actual_date", sa.Date(), nullable=True))
    op.add_column("briefs", sa.Column("actual_start_time", sa.Time(), nullable=True))
    op.add_column("briefs", sa.Column("actual_attendance", sa.Integer(), nullable=True))
    # final_apps may be lower than apps_submitted if applicants withdraw
    op.add_column("briefs", sa.Column("final_apps", sa.Integer(), nullable=True))

    # ── Trips table ──────────────────────────────────────────────────────────
    # Let op.create_table handle type creation naturally via the Enum definition
    op.create_table(
        "trips",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("agent_id", sa.String(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("start_date", sa.Date(), nullable=False),
        sa.Column("end_date", sa.Date(), nullable=False),
        sa.Column(
            "status",
            sa.Enum("planning", "confirmed", "completed", "cancelled", name="tripstatus"),
            nullable=False,
            server_default="planning",
        ),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("NOW()"),
        ),
    )
    op.create_index("ix_trips_agent_id", "trips", ["agent_id"])
    op.create_index("ix_trips_start_date", "trips", ["start_date"])

    # ── Trip → briefs junction ────────────────────────────────────────────────
    op.create_table(
        "trip_briefs",
        sa.Column(
            "trip_id",
            sa.String(),
            sa.ForeignKey("trips.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column(
            "brief_id",
            sa.String(),
            sa.ForeignKey("briefs.id", ondelete="CASCADE"),
            primary_key=True,
        ),
    )
    op.create_index("ix_trip_briefs_brief_id", "trip_briefs", ["brief_id"])

    # ── Link conversation logs to a specific brief ───────────────────────────
    # Agents log scheduling calls/emails — tying them to the brief being coordinated
    op.add_column(
        "conversation_logs",
        sa.Column(
            "brief_id",
            sa.String(),
            sa.ForeignKey("briefs.id", ondelete="SET NULL"),
            nullable=True,
        ),
    )
    op.create_index("ix_conversation_logs_brief_id", "conversation_logs", ["brief_id"])


def downgrade() -> None:
    op.drop_index("ix_conversation_logs_brief_id", table_name="conversation_logs")
    op.drop_column("conversation_logs", "brief_id")

    op.drop_index("ix_trip_briefs_brief_id", table_name="trip_briefs")
    op.drop_table("trip_briefs")

    op.drop_index("ix_trips_start_date", table_name="trips")
    op.drop_index("ix_trips_agent_id", table_name="trips")
    op.drop_table("trips")
    op.execute("DROP TYPE IF EXISTS tripstatus")

    op.drop_column("briefs", "final_apps")
    op.drop_column("briefs", "actual_attendance")
    op.drop_column("briefs", "actual_start_time")
    op.drop_column("briefs", "actual_date")
    op.alter_column("briefs", "status", server_default="scheduled")
    op.alter_column("briefs", "brief_date", nullable=False)
    # Note: PostgreSQL does not support removing enum values; downgrade leaves
    # 'draft' and 'outreach' in the briefstatus type.
