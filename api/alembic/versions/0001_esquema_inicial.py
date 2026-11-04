"""esquema inicial: users, pets, uploads, analyses, validations

Revision ID: 0001
Revises:
Create Date: 2026-11-04
"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql as pg

from alembic import op

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None

user_role = pg.ENUM("owner", "vet", "admin", name="user_role", create_type=False)
pet_sex = pg.ENUM("male", "female", "unknown", name="pet_sex", create_type=False)
risk_level = pg.ENUM("green", "yellow", "red", name="risk_level", create_type=False)
vet_assessment = pg.ENUM(
    "sin_signos", "con_signos", "no_evaluable", name="vet_assessment", create_type=False
)
ENUMS = (user_role, pet_sex, risk_level, vet_assessment)

# Solo claves temporales generadas por la API: tmp/<uuid>.jpg|png
OBJECT_KEY_REGEX = (
    r"^tmp/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|png)$"
)
MAX_UPLOAD_BYTES = 10 * 1024 * 1024


def _id() -> sa.Column:
    return sa.Column(
        "id", pg.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")
    )


def _created_at() -> sa.Column:
    return sa.Column(
        "created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
    )


def _updated_at() -> sa.Column:
    return sa.Column(
        "updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
    )


def upgrade() -> None:
    bind = op.get_bind()
    for enum in ENUMS:
        enum.create(bind)

    op.create_table(
        "users",
        _id(),
        sa.Column("firebase_uid", sa.Text(), nullable=False),
        sa.Column("email", sa.Text()),
        sa.Column("display_name", sa.Text()),
        sa.Column("role", user_role, nullable=False, server_default="owner"),
        _created_at(),
        _updated_at(),
        sa.UniqueConstraint("firebase_uid", name="uq_users_firebase_uid"),
    )

    op.create_table(
        "pets",
        _id(),
        sa.Column(
            "owner_id",
            pg.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE", name="fk_pets_owner_id_users"),
            nullable=False,
        ),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("breed", sa.Text()),
        sa.Column("sex", pet_sex, nullable=False, server_default="unknown"),
        sa.Column("birth_date", sa.Date()),
        sa.Column("weight_kg", sa.Numeric(5, 2)),
        _created_at(),
        _updated_at(),
        sa.CheckConstraint(
            "weight_kg IS NULL OR (weight_kg > 0 AND weight_kg < 120)", name="ck_pets_weight_kg"
        ),
    )
    op.create_index("ix_pets_owner_id", "pets", ["owner_id"])

    op.create_table(
        "uploads",
        sa.Column("object_key", sa.Text(), primary_key=True),
        sa.Column(
            "user_id",
            pg.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE", name="fk_uploads_user_id_users"),
            nullable=False,
        ),
        sa.Column("content_type", sa.Text(), nullable=False),
        sa.Column("content_length", sa.Integer(), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("consumed_at", sa.DateTime(timezone=True)),
        _created_at(),
        sa.CheckConstraint(f"object_key ~ '{OBJECT_KEY_REGEX}'", name="ck_uploads_object_key"),
        sa.CheckConstraint(
            "content_type IN ('image/jpeg', 'image/png')", name="ck_uploads_content_type"
        ),
        sa.CheckConstraint(
            f"content_length BETWEEN 1 AND {MAX_UPLOAD_BYTES}", name="ck_uploads_content_length"
        ),
    )
    op.create_index("ix_uploads_user_id", "uploads", ["user_id"])

    op.create_table(
        "analyses",
        _id(),
        sa.Column(
            "pet_id",
            pg.UUID(as_uuid=True),
            sa.ForeignKey("pets.id", ondelete="CASCADE", name="fk_analyses_pet_id_pets"),
            nullable=False,
        ),
        sa.Column("risk_level", risk_level, nullable=False),
        sa.Column("confidence", sa.Numeric(5, 4), nullable=False),
        sa.Column("probability_signs", sa.Numeric(5, 4), nullable=False),
        sa.Column("model_version", sa.Text(), nullable=False),
        sa.Column("recommendation", sa.Text(), nullable=False),
        sa.Column("blur_variance", sa.Double(), nullable=False),
        sa.Column("luminance", sa.Double(), nullable=False),
        sa.Column("image_width", sa.Integer(), nullable=False),
        sa.Column("image_height", sa.Integer(), nullable=False),
        sa.Column("inference_ms", sa.Integer(), nullable=False),
        sa.Column("image_consent", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("consent_at", sa.DateTime(timezone=True)),
        sa.Column("consent_policy_version", sa.Text()),
        sa.Column("consent_revoked_at", sa.DateTime(timezone=True)),
        sa.Column("image_key", sa.Text()),
        _created_at(),
        sa.CheckConstraint("confidence BETWEEN 0 AND 1", name="ck_analyses_confidence"),
        sa.CheckConstraint(
            "probability_signs BETWEEN 0 AND 1", name="ck_analyses_probability_signs"
        ),
        sa.CheckConstraint(
            "image_width > 0 AND image_height > 0", name="ck_analyses_image_dimensions"
        ),
        sa.CheckConstraint("inference_ms >= 0", name="ck_analyses_inference_ms"),
        # Ley 1581: sin consentimiento no puede quedar ninguna imagen asociada,
        # aunque la API tenga un bug.
        sa.CheckConstraint(
            "image_key IS NULL OR (image_consent AND consent_at IS NOT NULL)",
            name="ck_analyses_image_key_requires_consent",
        ),
        sa.CheckConstraint(
            "NOT image_consent OR (consent_at IS NOT NULL AND consent_policy_version IS NOT NULL)",
            name="ck_analyses_consent_complete",
        ),
        sa.CheckConstraint(
            "image_key IS NULL OR image_key LIKE 'permanent/%'",
            name="ck_analyses_image_key_permanent",
        ),
        sa.CheckConstraint(
            "consent_revoked_at IS NULL OR image_key IS NULL",
            name="ck_analyses_revoked_has_no_image",
        ),
    )
    op.create_index(
        "ix_analyses_pet_created",
        "analyses",
        ["pet_id", sa.text("created_at DESC")],
    )

    op.create_table(
        "validations",
        _id(),
        sa.Column(
            "analysis_id",
            pg.UUID(as_uuid=True),
            sa.ForeignKey(
                "analyses.id", ondelete="CASCADE", name="fk_validations_analysis_id_analyses"
            ),
            nullable=False,
        ),
        sa.Column(
            "vet_user_id",
            pg.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="RESTRICT", name="fk_validations_vet_user_id_users"),
            nullable=False,
        ),
        sa.Column("vet_assessment", vet_assessment, nullable=False),
        sa.Column("notes", sa.Text()),
        _created_at(),
        sa.UniqueConstraint(
            "analysis_id", "vet_user_id", name="uq_validations_analysis_id_vet_user_id"
        ),
    )


def downgrade() -> None:
    op.drop_table("validations")
    op.drop_index("ix_analyses_pet_created", table_name="analyses")
    op.drop_table("analyses")
    op.drop_index("ix_uploads_user_id", table_name="uploads")
    op.drop_table("uploads")
    op.drop_index("ix_pets_owner_id", table_name="pets")
    op.drop_table("pets")
    op.drop_table("users")
    bind = op.get_bind()
    for enum in reversed(ENUMS):
        enum.drop(bind)
