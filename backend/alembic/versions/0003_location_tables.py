"""bases and reserve_units tables

Hierarchy: regions → bases → reserve_units.

bases: physical armory / installation with a full structured address.
reserve_units: the military unit stationed at a base, carrying program,
               branch, organizational hierarchy fields, and CRM status.

Revision ID: 0003
Revises: 0002
Create Date: 2026-03-25
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0003"
down_revision: Union[str, None] = "0002"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── Bases ───────────────────────────────────────────────────────────────
    op.create_table(
        "bases",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("region_id", sa.String(), sa.ForeignKey("regions.id"), nullable=False),
        # Actual state this base is in (a region spans many states)
        sa.Column("state", sa.String(2), sa.ForeignKey("states.code"), nullable=True),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("address_street", sa.String(), nullable=True),
        sa.Column("address_city", sa.String(), nullable=True),
        sa.Column("address_zip", sa.String(), nullable=True),
        sa.Column("latitude", sa.Float(), nullable=True),
        sa.Column("longitude", sa.Float(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
    )
    op.create_index("ix_bases_region_id", "bases", ["region_id"])
    op.create_index("ix_bases_state", "bases", ["state"])

    # ── Reserve Units ────────────────────────────────────────────────────────
    op.create_table(
        "reserve_units",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("base_id", sa.String(), sa.ForeignKey("bases.id"), nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        # Military classification
        sa.Column(
            "branch",
            sa.Enum(
                "army", "air_force", "army_national_guard", "air_national_guard",
                "navy", "marines", "coast_guard", "space_force",
                name="branch",
            ),
            nullable=True,
        ),
        sa.Column(
            "program",
            sa.Enum("ssli", "rgli", name="program"),
            nullable=True,
        ),
        sa.Column("building_name", sa.String(), nullable=True),
        # Phones
        sa.Column("phone", sa.String(), nullable=True),
        sa.Column("phone_ext", sa.String(), nullable=True),
        sa.Column("additional_phone", sa.String(), nullable=True),
        # Organizational hierarchy
        sa.Column("end_strength", sa.Integer(), nullable=True),
        sa.Column("wing_bde", sa.String(), nullable=True),
        sa.Column("group_bn", sa.String(), nullable=True),
        sa.Column("unit_type", sa.String(), nullable=True),
        # CRM outreach tracking (separate from briefed status which is computed)
        sa.Column(
            "crm_status",
            sa.Enum(
                "uncontacted", "contacted", "scheduling", "scheduled",
                "briefed", "follow_up_needed", "inactive",
                name="crmstatus",
            ),
            nullable=False,
            server_default="uncontacted",
        ),
        # Denormalized briefing cache (kept current by service layer)
        sa.Column("last_briefed_date", sa.DateTime(timezone=True), nullable=True),
        sa.Column("next_follow_up_date", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_contacted_date", sa.DateTime(timezone=True), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
    )
    op.create_index("ix_reserve_units_base_id", "reserve_units", ["base_id"])
    op.create_index("ix_reserve_units_name", "reserve_units", ["name"])


def downgrade() -> None:
    op.drop_index("ix_reserve_units_name", table_name="reserve_units")
    op.drop_index("ix_reserve_units_base_id", table_name="reserve_units")
    op.drop_table("reserve_units")
    op.drop_index("ix_bases_state", table_name="bases")
    op.drop_index("ix_bases_region_id", table_name="bases")
    op.drop_table("bases")
    op.execute("DROP TYPE IF EXISTS crmstatus")
    op.execute("DROP TYPE IF EXISTS program")
    op.execute("DROP TYPE IF EXISTS branch")
