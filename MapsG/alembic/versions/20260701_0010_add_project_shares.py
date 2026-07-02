from alembic import op
import sqlalchemy as sa


revision = "20260701_0010"
down_revision = ("20260629_0009", "f46af2e9e003")
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "project_shares",
        sa.Column("id", sa.String(64), primary_key=True),
        sa.Column(
            "project_id",
            sa.String(64),
            sa.ForeignKey("projects.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("owner_user_id", sa.String(64), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("owner_company_id", sa.String(64), sa.ForeignKey("companies.id"), nullable=False),
        sa.Column("token", sa.String(160), nullable=False, unique=True),
        sa.Column("code", sa.String(30), nullable=False, unique=True),
        sa.Column("mode", sa.String(30), nullable=False, server_default="copy"),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("max_uses", sa.Integer(), nullable=False, server_default="10"),
        sa.Column("used_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("include_observations", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("include_only_ready_maps", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_project_shares_project_id", "project_shares", ["project_id"])
    op.create_index("ix_project_shares_owner_user_id", "project_shares", ["owner_user_id"])
    op.create_index("ix_project_shares_owner_company_id", "project_shares", ["owner_company_id"])
    op.create_index("ix_project_shares_token", "project_shares", ["token"])
    op.create_index("ix_project_shares_code", "project_shares", ["code"])

    op.create_table(
        "project_share_redemptions",
        sa.Column("id", sa.String(64), primary_key=True),
        sa.Column(
            "share_id",
            sa.String(64),
            sa.ForeignKey("project_shares.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("accepted_by_user_id", sa.String(64), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("accepted_by_company_id", sa.String(64), sa.ForeignKey("companies.id"), nullable=False),
        sa.Column("created_project_id", sa.String(64), sa.ForeignKey("projects.id"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_project_share_redemptions_share_id", "project_share_redemptions", ["share_id"])
    op.create_index(
        "ix_project_share_redemptions_accepted_by_user_id",
        "project_share_redemptions",
        ["accepted_by_user_id"],
    )
    op.create_index(
        "ix_project_share_redemptions_accepted_by_company_id",
        "project_share_redemptions",
        ["accepted_by_company_id"],
    )
    op.create_index(
        "ix_project_share_redemptions_created_project_id",
        "project_share_redemptions",
        ["created_project_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_project_share_redemptions_created_project_id", table_name="project_share_redemptions")
    op.drop_index("ix_project_share_redemptions_accepted_by_company_id", table_name="project_share_redemptions")
    op.drop_index("ix_project_share_redemptions_accepted_by_user_id", table_name="project_share_redemptions")
    op.drop_index("ix_project_share_redemptions_share_id", table_name="project_share_redemptions")
    op.drop_table("project_share_redemptions")

    op.drop_index("ix_project_shares_code", table_name="project_shares")
    op.drop_index("ix_project_shares_token", table_name="project_shares")
    op.drop_index("ix_project_shares_owner_company_id", table_name="project_shares")
    op.drop_index("ix_project_shares_owner_user_id", table_name="project_shares")
    op.drop_index("ix_project_shares_project_id", table_name="project_shares")
    op.drop_table("project_shares")
