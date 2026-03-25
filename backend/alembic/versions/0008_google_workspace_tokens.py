"""add Google Workspace OAuth token columns to users

Revision ID: 0008
Revises: 0007
Create Date: 2026-03-25
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0008"
down_revision: Union[str, None] = "0007"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("users", sa.Column("google_refresh_token", sa.Text(), nullable=True))
    op.add_column("users", sa.Column("google_token_scopes", sa.String(), nullable=True))
    op.add_column(
        "users",
        sa.Column("google_connected_at", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("users", "google_connected_at")
    op.drop_column("users", "google_token_scopes")
    op.drop_column("users", "google_refresh_token")
