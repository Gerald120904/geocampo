"""Initial GeoCampo schema."""

from alembic import op
import sqlalchemy as sa

revision = "20260625_0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    if op.get_bind().dialect.name == "postgresql":
        op.execute("CREATE EXTENSION IF NOT EXISTS postgis")
    op.create_table(
        "companies",
        sa.Column("id", sa.String(64), primary_key=True),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("legal_name", sa.String(250)),
        sa.Column("identifier", sa.String(100), nullable=False, unique=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_companies_name", "companies", ["name"])
    op.create_index("ix_companies_identifier", "companies", ["identifier"], unique=True)
    op.create_table(
        "users",
        sa.Column("id", sa.String(64), primary_key=True),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("email", sa.String(320), nullable=False, unique=True),
        sa.Column("password_hash", sa.String(255), nullable=False),
        sa.Column("role", sa.String(30), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column("company_id", sa.String(64), sa.ForeignKey("companies.id", ondelete="SET NULL")),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_users_email", "users", ["email"], unique=True)
    op.create_index("ix_users_role", "users", ["role"])
    op.create_index("ix_users_company_id", "users", ["company_id"])
    op.create_table(
        "projects",
        sa.Column("id", sa.String(64), primary_key=True),
        sa.Column("company_id", sa.String(64), sa.ForeignKey("companies.id", ondelete="CASCADE"), nullable=False),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("description", sa.Text()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_projects_company_id", "projects", ["company_id"])
    op.create_index("ix_projects_name", "projects", ["name"])
    op.create_table(
        "map_projects",
        sa.Column("id", sa.String(64), primary_key=True),
        sa.Column("project_id", sa.String(64), sa.ForeignKey("projects.id", ondelete="CASCADE"), nullable=False),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("description", sa.Text()),
        sa.Column("status", sa.String(30), nullable=False),
        sa.Column("source_type", sa.String(30), nullable=False),
        sa.Column("original_file_path", sa.Text(), nullable=False),
        sa.Column("processed_folder_path", sa.Text()),
        sa.Column("package_file_path", sa.Text()),
        sa.Column("preview_file_path", sa.Text()),
        sa.Column("bounds_geometry", sa.JSON()),
        sa.Column("center_lat", sa.Float()),
        sa.Column("center_lng", sa.Float()),
        sa.Column("min_zoom", sa.Integer(), nullable=False),
        sa.Column("max_zoom", sa.Integer(), nullable=False),
        sa.Column("default_zoom", sa.Integer(), nullable=False),
        sa.Column("crs_original", sa.String(100)),
        sa.Column("crs_app", sa.String(30), nullable=False),
        sa.Column("file_size_bytes", sa.BigInteger(), nullable=False),
        sa.Column("created_by", sa.String(64), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("processed_at", sa.DateTime(timezone=True)),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_map_projects_project_id", "map_projects", ["project_id"])
    op.create_index("ix_map_projects_status", "map_projects", ["status"])
    op.create_index("ix_map_projects_created_by", "map_projects", ["created_by"])
    op.create_table(
        "map_files",
        sa.Column("id", sa.String(64), primary_key=True),
        sa.Column("map_project_id", sa.String(64), sa.ForeignKey("map_projects.id", ondelete="CASCADE"), nullable=False),
        sa.Column("file_type", sa.String(30), nullable=False),
        sa.Column("original_name", sa.String(255), nullable=False),
        sa.Column("stored_name", sa.String(255), nullable=False),
        sa.Column("file_path", sa.Text(), nullable=False),
        sa.Column("mime_type", sa.String(150)),
        sa.Column("size_bytes", sa.BigInteger(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_map_files_map_project_id", "map_files", ["map_project_id"])
    op.create_index("ix_map_files_file_type", "map_files", ["file_type"])
    op.create_table(
        "map_layers",
        sa.Column("id", sa.String(64), primary_key=True),
        sa.Column("map_project_id", sa.String(64), sa.ForeignKey("map_projects.id", ondelete="CASCADE"), nullable=False),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("layer_key", sa.String(150), nullable=False),
        sa.Column("layer_type", sa.String(30), nullable=False),
        sa.Column("geometry_type", sa.String(50)),
        sa.Column("file_path", sa.Text(), nullable=False),
        sa.Column("visible_default", sa.Boolean(), nullable=False),
        sa.Column("opacity_default", sa.Float(), nullable=False),
        sa.Column("properties_schema", sa.JSON()),
        sa.Column("feature_count", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_map_layers_map_project_id", "map_layers", ["map_project_id"])
    op.create_table(
        "processing_jobs",
        sa.Column("id", sa.String(64), primary_key=True),
        sa.Column("map_project_id", sa.String(64), sa.ForeignKey("map_projects.id", ondelete="CASCADE"), nullable=False),
        sa.Column("status", sa.String(30), nullable=False),
        sa.Column("step", sa.String(100), nullable=False),
        sa.Column("progress", sa.Integer(), nullable=False),
        sa.Column("error_message", sa.Text()),
        sa.Column("started_at", sa.DateTime(timezone=True)),
        sa.Column("finished_at", sa.DateTime(timezone=True)),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_processing_jobs_map_project_id", "processing_jobs", ["map_project_id"])
    op.create_index("ix_processing_jobs_status", "processing_jobs", ["status"])
    op.create_table(
        "field_observations",
        sa.Column("id", sa.String(64), primary_key=True),
        sa.Column("map_project_id", sa.String(64), sa.ForeignKey("map_projects.id"), nullable=False),
        sa.Column("user_id", sa.String(64), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("description", sa.Text()),
        sa.Column("observation_type", sa.String(100)),
        sa.Column("lat", sa.Float(), nullable=False),
        sa.Column("lng", sa.Float(), nullable=False),
        sa.Column("accuracy", sa.Float()),
        sa.Column("photo_path", sa.Text()),
        sa.Column("properties", sa.JSON()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("synced_at", sa.DateTime(timezone=True)),
    )
    op.create_index("ix_field_observations_map_project_id", "field_observations", ["map_project_id"])
    op.create_index("ix_field_observations_user_id", "field_observations", ["user_id"])


def downgrade() -> None:
    for table in (
        "field_observations",
        "processing_jobs",
        "map_layers",
        "map_files",
        "map_projects",
        "projects",
        "users",
        "companies",
    ):
        op.drop_table(table)
