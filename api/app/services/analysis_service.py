"""Registro de un escaneo dental hecho con el SDK de AI for Pet.

La foto nunca pasa por esta API: el SDK la toma, la analiza en los servidores de AI for Pet
y entrega a la app un JSON. La app lo envía aquí para guardarlo en el historial.
"""

import logging
import uuid
from dataclasses import dataclass
from typing import Any

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.core.errors import ConflictError, UnprocessableError
from app.models import Analysis, Pet, User
from app.services.aiforpet import ToothScan, parse_tooth_scan
from app.services.pet_service import get_owned_pet

logger = logging.getLogger("app.analysis")


@dataclass(frozen=True)
class ScanSubmission:
    pet_id: uuid.UUID
    client_scan_id: uuid.UUID
    sdk_platform: str
    sdk_version: str
    result: dict[str, Any]
    result_size: int


@dataclass(frozen=True)
class RegisteredAnalysis:
    analysis: Analysis
    created: bool


def _same_uuid(value: str | None, expected: uuid.UUID) -> bool:
    try:
        return value is not None and uuid.UUID(value) == expected
    except ValueError:
        return False


def _ensure_result_belongs(scan: ToothScan, user: User, pet: Pet) -> None:
    """La app le pasa al SDK nuestro id de usuario y de mascota; el SDK los devuelve."""
    if scan.user_id is not None and not _same_uuid(scan.user_id, user.id):
        raise UnprocessableError(
            "scan_result_mismatch", "El resultado del escaneo no corresponde a tu usuario."
        )
    if scan.pet_id is not None and not _same_uuid(scan.pet_id, pet.id):
        raise UnprocessableError(
            "scan_result_mismatch", "El resultado del escaneo no corresponde a esta mascota."
        )


def _previous(db: Session, user: User, submission: ScanSubmission) -> RegisteredAnalysis | None:
    """Si la app reintenta el envío del mismo escaneo, devuelve el análisis ya guardado."""
    row = db.execute(
        select(Analysis, Pet.owner_id)
        .join(Pet, Pet.id == Analysis.pet_id)
        .where(Analysis.client_scan_id == submission.client_scan_id)
    ).one_or_none()
    if row is None:
        return None
    analysis, owner_id = row
    if owner_id != user.id or analysis.pet_id != submission.pet_id:
        raise ConflictError(
            "scan_id_conflict", "Ese escaneo ya fue registrado con otros datos. Repite el escaneo."
        )
    return RegisteredAnalysis(analysis=analysis, created=False)


def register_scan(
    db: Session, settings: Settings, user: User, submission: ScanSubmission
) -> RegisteredAnalysis:
    previous = _previous(db, user, submission)
    if previous is not None:
        return previous

    if user.consent_policy_version != settings.consent_policy_version:
        raise ConflictError(
            "consent_required",
            "Debes aceptar la autorización de tratamiento de datos vigente antes de analizar.",
        )

    pet = get_owned_pet(db, user, submission.pet_id)
    scan = parse_tooth_scan(submission.result, raw_size=submission.result_size)
    _ensure_result_belongs(scan, user, pet)

    analysis = Analysis(
        id=uuid.uuid4(),
        pet_id=pet.id,
        client_scan_id=submission.client_scan_id,
        risk_level=scan.risk_level,
        provider_status=scan.provider_status,
        part=scan.part,
        sub_part=scan.sub_part,
        findings=[finding.as_dict() for finding in scan.findings],
        provider_result=submission.result,
        provider_analyzed_at=scan.analyzed_at,
        model_version=f"aiforpet-scansdk-{submission.sdk_platform}/{submission.sdk_version}",
        recommendation=scan.recommendation,
        consent_policy_version=settings.consent_policy_version,
    )
    db.add(analysis)
    try:
        db.commit()
    except IntegrityError:
        # Dos envíos simultáneos del mismo escaneo: gana el primero.
        db.rollback()
        previous = _previous(db, user, submission)
        if previous is None:
            raise
        return previous

    logger.info(
        "Análisis %s registrado: estado=%s nivel=%s hallazgos=%s",
        analysis.id,
        scan.provider_status,
        scan.risk_level.value,
        [f"{f.code}:{f.status}" for f in scan.findings],
    )
    return RegisteredAnalysis(analysis=analysis, created=True)
