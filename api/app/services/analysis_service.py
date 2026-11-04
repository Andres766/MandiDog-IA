"""Orquesta el análisis: pertenencia → validación del objeto → calidad → inferencia →
consentimiento → persistencia. El temporal en tmp/ nunca se conserva."""

import logging
import time
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import NoReturn

from sqlalchemy.orm import Session

from app.core.config import Settings
from app.core.errors import AppError, ConflictError, NotFoundError, UnprocessableError
from app.inference.base import InferenceBackend
from app.models import Analysis, Upload, User
from app.services.image_quality import QualityThresholds, assess_quality
from app.services.pet_service import get_owned_pet
from app.services.preprocessing import preprocess
from app.services.risk import assess_risk
from app.services.storage import PERMANENT_PREFIX, TMP_PREFIX, Storage, StorageError
from app.services.upload_service import EXTENSIONS, claim_upload

logger = logging.getLogger("app.analysis")


@dataclass(frozen=True)
class AnalysisRequest:
    pet_id: uuid.UUID
    object_key: str
    image_consent: bool
    consent_policy_version: str | None


class AnalysisService:
    def __init__(
        self, db: Session, storage: Storage, inference: InferenceBackend, settings: Settings
    ) -> None:
        self.db = db
        self.storage = storage
        self.inference = inference
        self.settings = settings

    def create(self, user: User, request: AnalysisRequest) -> Analysis:
        settings = self.settings
        if (
            request.image_consent
            and request.consent_policy_version != settings.consent_policy_version
        ):
            raise ConflictError(
                "consent_policy_outdated",
                "El texto de autorización cambió. Actualiza la app y vuelve a leerlo.",
            )

        pet = get_owned_pet(self.db, user, request.pet_id)
        upload = claim_upload(self.db, user, request.object_key)

        # 1. Validar el objeto con head_object ANTES de descargarlo.
        info = self.storage.head(upload.object_key)
        if info is None:
            self.db.rollback()  # deshace el reclamo: la app puede reintentar la subida
            raise NotFoundError(
                "upload_missing", "La foto no terminó de subirse. Vuelve a intentarlo."
            )
        if (
            info.size > settings.upload_max_bytes
            or info.size != upload.content_length
            or info.content_type != upload.content_type
        ):
            self._reject(
                upload,
                UnprocessableError(
                    "upload_mismatch",
                    "La foto recibida no coincide con la autorizada. Tómala de nuevo.",
                ),
            )

        # 2. Descargar y controlar calidad.
        data = self.storage.download(upload.object_key, max_bytes=settings.upload_max_bytes)
        report = assess_quality(
            data,
            upload.content_type,
            QualityThresholds(
                min_side_px=settings.quality_min_side_px,
                min_blur_variance=settings.quality_min_blur_variance,
                min_luminance=settings.quality_min_luminance,
                max_luminance=settings.quality_max_luminance,
            ),
        )
        if not report.ok:
            self._reject(
                upload,
                UnprocessableError(
                    "image_quality",
                    "La foto no tiene la calidad suficiente para analizarla.",
                    details=[{"code": i.code, "message": i.message} for i in report.issues],
                ),
            )
        assert report.image is not None

        # 3. Preprocesar e inferir.
        batch = preprocess(report.image, self.inference.preprocessing)
        started = time.perf_counter()
        probability = self.inference.predict(batch)
        inference_ms = round((time.perf_counter() - started) * 1000)
        risk = assess_risk(
            probability,
            yellow=settings.risk_threshold_yellow,
            red=settings.risk_threshold_red,
        )

        analysis = Analysis(
            id=uuid.uuid4(),
            pet_id=pet.id,
            risk_level=risk.level,
            confidence=risk.confidence,
            probability_signs=risk.probability_signs,
            model_version=self.inference.version,
            recommendation=risk.recommendation,
            blur_variance=report.blur_variance,
            luminance=report.luminance,
            image_width=report.width,
            image_height=report.height,
            inference_ms=inference_ms,
            image_consent=request.image_consent,
        )

        # 4. Consentimiento: solo con autorización se copia a permanent/.
        permanent_key: str | None = None
        if request.image_consent:
            permanent_key = f"{PERMANENT_PREFIX}{analysis.id}.{EXTENSIONS[upload.content_type]}"
            self.storage.copy(upload.object_key, permanent_key)
            analysis.image_key = permanent_key
            analysis.consent_at = datetime.now(UTC)
            analysis.consent_policy_version = settings.consent_policy_version

        self.db.add(analysis)
        try:
            self.db.commit()
        except Exception:
            self.db.rollback()
            if permanent_key:
                self._delete_quietly(permanent_key)
            raise

        self._delete_quietly(upload.object_key)
        logger.info(
            "Análisis %s: nivel=%s p=%.4f inferencia=%dms consentimiento=%s",
            analysis.id,
            risk.level.value,
            risk.probability_signs,
            inference_ms,
            request.image_consent,
        )
        return analysis

    def _reject(self, upload: Upload, error: AppError) -> NoReturn:
        """Rechazo definitivo: se borra el temporal y la carga queda consumida."""
        self._delete_quietly(upload.object_key)
        self.db.commit()
        raise error

    def _delete_quietly(self, key: str) -> None:
        try:
            self.storage.delete(key)
        except StorageError:
            if key.startswith(TMP_PREFIX):
                logger.warning("No se pudo borrar %s; lo borrará la regla de ciclo de vida", key)
            else:
                logger.error("No se pudo borrar %s: objeto huérfano, revisar a mano", key)
