from alembic import op
import sqlalchemy as sa


revision = "20260629_0008"
down_revision = "20260629_0007"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "map_projects",
        sa.Column("quick_mbtiles_file_path", sa.Text(), nullable=True),
    )
    op.add_column(
        "map_projects",
        sa.Column("quick_min_zoom", sa.Integer(), nullable=True),
    )
    op.add_column(
        "map_projects",
        sa.Column("quick_max_zoom", sa.Integer(), nullable=True),
    )
    op.add_column(
        "map_projects",
        sa.Column("quick_default_zoom", sa.Integer(), nullable=True),
    )
    op.add_column(
        "map_projects",
        sa.Column("quick_created_at", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("map_projects", "quick_created_at")
    op.drop_column("map_projects", "quick_default_zoom")
    op.drop_column("map_projects", "quick_max_zoom")
    op.drop_column("map_projects", "quick_min_zoom")
    op.drop_column("map_projects", "quick_mbtiles_file_path")
