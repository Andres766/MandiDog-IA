"""integración con AI for Pet: el análisis lo hace su SDK, sin carga propia de imágenes

- Se elimina la tabla uploads (ya no hay URLs firmadas ni almacenamiento propio).
- analyses guarda el resultado del SDK (estado, hallazgos y JSON original) en lugar de
  probabilidades, métricas de calidad e imagen conservada.
- La autorización de tratamiento de datos pasa a registrarse por usuario.

Revision ID: 0002
Revises: 0001
Create Date: 2026-11-04
"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql as pg

from alembic import op

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None

OLD_ANALYSIS_CHECKS = {
    "ck_analyses_confidence": "confidence BETWEEN 0 AND 1",
    "ck_analyses_probability_signs": "probability_signs BETWEEN 0 AND 1",
    "ck_analyses_image_dimensions": "image_width > 0 AND image_height > 0",
    "ck_analyses_inference_ms": "inference_ms >= 0",
    "ck_analyses_image_key_requires_consent": (
        "image_key IS NULL OR (image_consent AND consent_at IS NOT NULL)"
    ),
    "ck_analyses_consent_complete": (
        "NOT image_consent OR (consent_at IS NOT NULL AND consent_policy_version IS NOT NULL)"
    ),
    "ck_analyses_image_key_permanent": "image_key IS NULL OR image_key LIKE 'permanent/%'",
    "ck_analyses_revoked_has_no_image": "consent_revoked_at IS NULL OR image_key IS NULL",
}


def _old_analysis_columns() -> list[sa.Column]:
    return [
        sa.Column("confidence", sa.Numeric(5, 4), nullable=False),
        sa.Column("probability_signs", sa.Numeric(5, 4), nullable=False),
        sa.Column("blur_variance", sa.Double(), nullable=False),
        sa.Column("luminance", sa.Double(), nullable=False),
        sa.Column("image_width", sa.Integer(), nullable=False),
        sa.Column("image_height", sa.Integer(), nullable=False),
        sa.Column("inference_ms", sa.Integer(), nullable=False),
        sa.Column("image_consent", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("consent_at", sa.DateTime(timezone=True)),
        sa.Column("consent_revoked_at", sa.DateTime(timezone=True)),
        sa.Column("image_key", sa.Text()),
    ]


NEW_ANALYSIS_CHECKS = {
    "ck_analyses_provider_status": "provider_status IN ('NORMAL', 'CAUTION', 'WARNING')",
    # El semáforo debe corresponder exactamente al estado que devolvió AI for Pet.
    "ck_analyses_risk_matches_status": (
        "(provider_status = 'NORMAL' AND risk_level = 'green')"
        " OR (provider_status = 'CAUTION' AND risk_level = 'yellow')"
        " OR (provider_status = 'WARNING' AND risk_level = 'red')"
    ),
    "ck_analyses_part": "part = 'TOOTH'",
    "ck_analyses_sub_part": "sub_part IS NULL OR sub_part IN ('TLEFT', 'TCENTER', 'TRIGHT')",
    "ck_analyses_findings_array": "jsonb_typeof(findings) = 'array'",
    "ck_analyses_provider_result_object": "jsonb_typeof(provider_result) = 'object'",
    "ck_analyses_consent_policy_version": "length(consent_policy_version) > 0",
}
NEW_ANALYSIS_COLUMNS = (
    "client_scan_id",
    "provider_status",
    "part",
    "sub_part",
    "findings",
    "provider_result",
    "provider_analyzed_at",
)


def upgrade() -> None:
    op.drop_index("ix_uploads_user_id", table_name="uploads")
    op.drop_table("uploads")

    # Los análisis anteriores venían del stub (resultados fijos de desarrollo) y no tienen
    # equivalente en el formato de AI for Pet. No hubo datos de producción.
    op.execute("DELETE FROM analyses")
    for name in OLD_ANALYSIS_CHECKS:
        op.drop_constraint(name, "analyses", type_="check")
    for column in _old_analysis_columns():
        op.drop_column("analyses", column.name)

    op.add_column("analyses", sa.Column("client_scan_id", pg.UUID(as_uuid=True), nullable=False))
    op.add_column("analyses", sa.Column("provider_status", sa.Text(), nullable=False))
    op.add_column("analyses", sa.Column("part", sa.Text(), nullable=False))
    op.add_column("analyses", sa.Column("sub_part", sa.Text()))
    op.add_column("analyses", sa.Column("findings", pg.JSONB(), nullable=False))
    op.add_column("analyses", sa.Column("provider_result", pg.JSONB(), nullable=False))
    op.add_column("analyses", sa.Column("provider_analyzed_at", sa.DateTime(timezone=True)))
    op.alter_column("analyses", "consent_policy_version", nullable=False)
    op.create_unique_constraint("uq_analyses_client_scan_id", "analyses", ["client_scan_id"])
    for name, condition in NEW_ANALYSIS_CHECKS.items():
        op.create_check_constraint(name, "analyses", condition)

    op.add_column("users", sa.Column("consent_policy_version", sa.Text()))
    op.add_column("users", sa.Column("consent_at", sa.DateTime(timezone=True)))
    op.create_check_constraint(
        "ck_users_consent_complete",
        "users",
        "(consent_policy_version IS NULL) = (consent_at IS NULL)",
    )


def downgrade() -> None:
    op.drop_constraint("ck_users_consent_complete", "users", type_="check")
    op.drop_column("users", "consent_at")
    op.drop_column("users", "consent_policy_version")

    op.execute("DELETE FROM analyses")
    for name in NEW_ANALYSIS_CHECKS:
        op.drop_constraint(name, "analyses", type_="check")
    op.drop_constraint("uq_analyses_client_scan_id", "analyses", type_="unique")
    for column in NEW_ANALYSIS_COLUMNS:
        op.drop_column("analyses", column)
    op.alter_column("analyses", "consent_policy_version", nullable=True)
    for column in _old_analysis_columns():
        op.add_column("analyses", column)
    for name, condition in OLD_ANALYSIS_CHECKS.items():
        op.create_check_constraint(name, "analyses", condition)

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
        sa.Column(
            "created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
        sa.CheckConstraint(
            r"object_key ~ '^tmp/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|png)$'",
            name="ck_uploads_object_key",
        ),
        sa.CheckConstraint(
            "content_type IN ('image/jpeg', 'image/png')", name="ck_uploads_content_type"
        ),
        sa.CheckConstraint(
            "content_length BETWEEN 1 AND 10485760", name="ck_uploads_content_length"
        ),
    )
    op.create_index("ix_uploads_user_id", "uploads", ["user_id"])
