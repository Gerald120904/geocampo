from alembic import op
import sqlalchemy as sa


revision = "20260629_0009"
down_revision = "20260629_0008"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "map_projects",
        sa.Column("raw_view_ready_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "map_projects",
        sa.Column("raw_bounds_geometry", sa.JSON(), nullable=True),
    )
    op.add_column(
        "map_projects",
        sa.Column("raw_center_lat", sa.Float(), nullable=True),
    )
    op.add_column(
        "map_projects",
        sa.Column("raw_center_lng", sa.Float(), nullable=True),
    )
    op.add_column(
        "map_projects",
        sa.Column("raw_pdf_page", sa.Integer(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("map_projects", "raw_pdf_page")
    op.drop_column("map_projects", "raw_center_lng")
    op.drop_column("map_projects", "raw_center_lat")
    op.drop_column("map_projects", "raw_bounds_geometry")
    op.drop_column("map_projects", "raw_view_ready_at")
