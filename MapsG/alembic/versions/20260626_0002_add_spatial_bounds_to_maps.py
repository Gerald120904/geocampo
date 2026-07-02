"""Add spatial bounds to maps."""

from alembic import op
import sqlalchemy as sa
import geoalchemy2

revision = "20260626_0002"
down_revision = "20260625_0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "map_projects",
        sa.Column(
            "bounds_geom",
            geoalchemy2.Geometry(geometry_type="POLYGON", srid=4326),
            nullable=True,
        ),
    )
    if op.get_bind().dialect.name == "postgresql":
        op.create_index(
            "ix_map_projects_bounds_geom",
            "map_projects",
            ["bounds_geom"],
            postgresql_using="gist",
        )


def downgrade() -> None:
    if op.get_bind().dialect.name == "postgresql":
        op.drop_index("ix_map_projects_bounds_geom", table_name="map_projects")
    op.drop_column("map_projects", "bounds_geom")
