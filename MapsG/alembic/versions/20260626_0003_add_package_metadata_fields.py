"""Add package metadata fields."""

from alembic import op
import sqlalchemy as sa

revision = "20260626_0003"
down_revision = "20260626_0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("map_projects", sa.Column("package_version", sa.String(30), nullable=True))
    op.add_column("map_projects", sa.Column("package_size_bytes", sa.BigInteger(), nullable=True))
    op.add_column("map_projects", sa.Column("package_checksum_sha256", sa.String(64), nullable=True))
    op.add_column("map_projects", sa.Column("package_created_at", sa.DateTime(timezone=True), nullable=True))


def downgrade() -> None:
    op.drop_column("map_projects", "package_created_at")
    op.drop_column("map_projects", "package_checksum_sha256")
    op.drop_column("map_projects", "package_size_bytes")
    op.drop_column("map_projects", "package_version")
