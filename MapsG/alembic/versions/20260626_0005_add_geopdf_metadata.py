"""Add geopdf metadata fields."""

from typing import Sequence, Union

from alembic import op
import geoalchemy2
import sqlalchemy as sa


revision: str = "20260626_0005"
down_revision: Union[str, None] = "f46af2e9e003"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("map_projects", sa.Column("footprint_geometry", sa.JSON(), nullable=True))

    op.add_column(
        "map_projects",
        sa.Column(
            "footprint_geom",
            geoalchemy2.Geometry(
                geometry_type="POLYGON",
                srid=4326,
                spatial_index=False,
            ),
            nullable=True,
        ),
    )

    op.add_column("map_projects", sa.Column("georef_metadata", sa.JSON(), nullable=True))
    op.add_column("map_projects", sa.Column("raster_width", sa.Integer(), nullable=True))
    op.add_column("map_projects", sa.Column("raster_height", sa.Integer(), nullable=True))
    op.add_column("map_projects", sa.Column("georef_method", sa.String(50), nullable=True))
    op.add_column("map_projects", sa.Column("pdf_page_count", sa.Integer(), nullable=True))
    op.add_column("map_projects", sa.Column("pdf_selected_page", sa.Integer(), nullable=True))
    op.add_column("map_projects", sa.Column("processing_message", sa.Text(), nullable=True))

    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        op.create_index(
            "ix_map_projects_footprint_geom",
            "map_projects",
            ["footprint_geom"],
            postgresql_using="gist",
        )


def downgrade() -> None:
    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        op.drop_index("ix_map_projects_footprint_geom", table_name="map_projects")

    op.drop_column("map_projects", "processing_message")
    op.drop_column("map_projects", "pdf_selected_page")
    op.drop_column("map_projects", "pdf_page_count")
    op.drop_column("map_projects", "georef_method")
    op.drop_column("map_projects", "raster_height")
    op.drop_column("map_projects", "raster_width")
    op.drop_column("map_projects", "georef_metadata")
    op.drop_column("map_projects", "footprint_geom")
    op.drop_column("map_projects", "footprint_geometry")
