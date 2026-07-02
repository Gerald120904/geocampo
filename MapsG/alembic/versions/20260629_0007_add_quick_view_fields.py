from alembic import op
import sqlalchemy as sa


revision = "20260629_0007"
down_revision = "20260627_0006"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "map_projects",
        sa.Column("quick_view_file_path", sa.Text(), nullable=True),
    )
    op.add_column(
        "map_projects",
        sa.Column("quick_view_created_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "map_projects",
        sa.Column(
            "active_view_mode",
            sa.String(length=30),
            nullable=False,
            server_default="auto",
        ),
    )


def downgrade() -> None:
    op.drop_column("map_projects", "active_view_mode")
    op.drop_column("map_projects", "quick_view_created_at")
    op.drop_column("map_projects", "quick_view_file_path")
