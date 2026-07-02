"""Add auth token attempts metadata."""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "f46af2e9e003"
down_revision: Union[str, None] = "20260626_0004"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "auth_tokens",
        sa.Column("attempts", sa.Integer(), nullable=False, server_default="0"),
    )

    op.alter_column("auth_tokens", "attempts", server_default=None)


def downgrade() -> None:
    op.drop_column("auth_tokens", "attempts")
