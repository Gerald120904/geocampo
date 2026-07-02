"""add map duplicate fields

Revision ID: 20260627_0006
Revises: 20260626_0005
Create Date: 2026-06-27
"""

from alembic import op
import sqlalchemy as sa


revision = "20260627_0006"
down_revision = "20260626_0005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("map_projects", sa.Column("spatial_fingerprint", sa.String(120), nullable=True))
    op.add_column("map_projects", sa.Column("file_checksum_sha256", sa.String(64), nullable=True))
    op.add_column("map_projects", sa.Column("duplicate_of_map_id", sa.String(64), nullable=True))
    op.add_column("map_projects", sa.Column("duplicate_score", sa.Float(), nullable=True))
    op.add_column("map_projects", sa.Column("duplicate_reason", sa.String(120), nullable=True))
    op.add_column("map_projects", sa.Column("replaced_by_map_id", sa.String(64), nullable=True))
    op.add_column("map_projects", sa.Column("archived_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("map_projects", sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True))
    op.create_index("ix_map_projects_spatial_fingerprint", "map_projects", ["spatial_fingerprint"])
    op.create_index("ix_map_projects_file_checksum_sha256", "map_projects", ["file_checksum_sha256"])


def downgrade() -> None:
    op.drop_index("ix_map_projects_file_checksum_sha256", table_name="map_projects")
    op.drop_index("ix_map_projects_spatial_fingerprint", table_name="map_projects")
    op.drop_column("map_projects", "deleted_at")
    op.drop_column("map_projects", "archived_at")
    op.drop_column("map_projects", "replaced_by_map_id")
    op.drop_column("map_projects", "duplicate_reason")
    op.drop_column("map_projects", "duplicate_score")
    op.drop_column("map_projects", "duplicate_of_map_id")
    op.drop_column("map_projects", "file_checksum_sha256")
    op.drop_column("map_projects", "spatial_fingerprint")
