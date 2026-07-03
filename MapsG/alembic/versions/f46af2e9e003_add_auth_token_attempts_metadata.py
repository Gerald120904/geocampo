"""Add auth token attempts metadata."""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "f46af2e9e003"
down_revision: Union[str, None] = "20260626_0004"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _has_column(table_name: str, column_name: str) -> bool:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    return any(
        column["name"] == column_name
        for column in inspector.get_columns(table_name)
    )


def upgrade() -> None:
    bind = op.get_bind()

    if not _has_column("auth_tokens", "attempts"):
        op.add_column(
            "auth_tokens",
            sa.Column("attempts", sa.Integer(), nullable=False, server_default="0"),
        )

    if bind.dialect.name == "postgresql":
        op.alter_column(
            "auth_tokens",
            "attempts",
            server_default=None,
            existing_type=sa.Integer(),
            existing_nullable=False,
        )


def downgrade() -> None:
    if _has_column("auth_tokens", "attempts"):
        op.drop_column("auth_tokens", "attempts")
