"""Validación clínica ciega de los resultados de AI for Pet.

Un veterinario valora cada caso SIN ver la predicción (sin_signos, con_signos o
no_evaluable). Solo después de registrar su valoración se le revela el resultado de la IA.
Con esas parejas se calcula la concordancia: sensibilidad, especificidad y exactitud,
en total, por biotipo cefálico y por raza.

Criterio: la IA "ve signos" cuando el estado de AI for Pet no es NORMAL (CAUTION o
WARNING). Los casos no_evaluable se reportan aparte y no entran en la matriz.
"""

import unicodedata
import uuid
from dataclasses import dataclass, field
from datetime import date

from sqlalchemy import exists, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.errors import ConflictError, NotFoundError
from app.models import Analysis, Pet, User, Validation, VetAssessment
from app.schemas.analysis import crop_image_urls

# Razas braquicéfalas frecuentes (comparación sin tildes ni mayúsculas).
_BRACHYCEPHALIC = (
    "pug",
    "carlino",
    "bulldog",
    "boxer",
    "shih tzu",
    "shihtzu",
    "boston terrier",
    "pekines",
    "lhasa apso",
    "cavalier",
    "dogo de burdeos",
    "bullmastiff",
    "chow chow",
    "shar pei",
    "affenpinscher",
    "grifon",
    "japanese chin",
    "chin japones",
)


def _normalize(text: str) -> str:
    decomposed = unicodedata.normalize("NFKD", text.lower().strip())
    return "".join(c for c in decomposed if not unicodedata.combining(c))


def cephalic_group(breed: str | None) -> str:
    if not breed or not breed.strip():
        return "Sin raza registrada"
    name = _normalize(breed)
    if any(b in name for b in _BRACHYCEPHALIC):
        return "Braquicéfalo"
    return "No braquicéfalo o sin clasificar"


def ai_sees_signs(analysis: Analysis) -> bool:
    return analysis.provider_status != "NORMAL"


def _crop_urls(analysis: Analysis) -> list[str]:
    """Recortes de la foto analizada (nunca los mapas de calor, que delatan la predicción)."""
    return crop_image_urls(analysis.provider_result)


@dataclass(frozen=True)
class PendingCase:
    analysis_id: uuid.UUID
    created_at: object
    sub_part: str | None
    pet_name: str
    breed: str | None
    sex: str
    birth_date: date | None
    photo_urls: list[str]


def pending_cases(db: Session, vet: User, *, limit: int) -> list[PendingCase]:
    already = exists().where(
        Validation.analysis_id == Analysis.id, Validation.vet_user_id == vet.id
    )
    rows = db.execute(
        select(Analysis, Pet)
        .join(Pet, Pet.id == Analysis.pet_id)
        .where(~already)
        .order_by(Analysis.created_at)
        .limit(limit)
    ).all()
    return [
        PendingCase(
            analysis_id=analysis.id,
            created_at=analysis.created_at,
            sub_part=analysis.sub_part,
            pet_name=pet.name,
            breed=pet.breed,
            sex=pet.sex.value,
            birth_date=pet.birth_date,
            photo_urls=_crop_urls(analysis),
        )
        for analysis, pet in rows
    ]


@dataclass(frozen=True)
class Reveal:
    validation: Validation
    analysis: Analysis
    agreement: bool | None


def submit_validation(
    db: Session,
    vet: User,
    analysis_id: uuid.UUID,
    assessment: VetAssessment,
    notes: str | None,
) -> Reveal:
    analysis = db.get(Analysis, analysis_id)
    if analysis is None:
        raise NotFoundError("analysis_not_found", "No encontramos ese caso.")
    validation = Validation(
        analysis_id=analysis.id,
        vet_user_id=vet.id,
        vet_assessment=assessment,
        notes=(notes or "").strip() or None,
    )
    db.add(validation)
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise ConflictError(
            "already_validated", "Ya registraste tu valoración para este caso."
        ) from exc
    db.refresh(validation)
    agreement = (
        None
        if assessment == VetAssessment.NO_EVALUABLE
        else (assessment == VetAssessment.CON_SIGNOS) == ai_sees_signs(analysis)
    )
    return Reveal(validation=validation, analysis=analysis, agreement=agreement)


@dataclass
class Matrix:
    """Matriz de confusión con el veterinario como referencia."""

    true_positive: int = 0
    false_positive: int = 0
    false_negative: int = 0
    true_negative: int = 0

    def add(self, vet_positive: bool, ai_positive: bool) -> None:
        if vet_positive and ai_positive:
            self.true_positive += 1
        elif vet_positive:
            self.false_negative += 1
        elif ai_positive:
            self.false_positive += 1
        else:
            self.true_negative += 1

    @property
    def total(self) -> int:
        return self.true_positive + self.false_positive + self.false_negative + self.true_negative

    @staticmethod
    def _ratio(num: int, den: int) -> float | None:
        return round(num / den, 4) if den else None

    def as_dict(self) -> dict[str, object]:
        return {
            "n": self.total,
            "true_positive": self.true_positive,
            "false_positive": self.false_positive,
            "false_negative": self.false_negative,
            "true_negative": self.true_negative,
            "sensitivity": self._ratio(
                self.true_positive, self.true_positive + self.false_negative
            ),
            "specificity": self._ratio(
                self.true_negative, self.true_negative + self.false_positive
            ),
            "accuracy": self._ratio(self.true_positive + self.true_negative, self.total),
        }


@dataclass
class Summary:
    overall: Matrix = field(default_factory=Matrix)
    by_cephalic_group: dict[str, Matrix] = field(default_factory=dict)
    by_breed: dict[str, Matrix] = field(default_factory=dict)
    not_evaluable: int = 0
    validations: int = 0


def summary(db: Session) -> Summary:
    rows = db.execute(
        select(Validation.vet_assessment, Analysis, Pet.breed)
        .join(Analysis, Analysis.id == Validation.analysis_id)
        .join(Pet, Pet.id == Analysis.pet_id)
    ).all()
    result = Summary(validations=len(rows))
    for assessment, analysis, breed in rows:
        if assessment == VetAssessment.NO_EVALUABLE:
            result.not_evaluable += 1
            continue
        vet_positive = assessment == VetAssessment.CON_SIGNOS
        ai_positive = ai_sees_signs(analysis)
        result.overall.add(vet_positive, ai_positive)
        group = cephalic_group(breed)
        result.by_cephalic_group.setdefault(group, Matrix()).add(vet_positive, ai_positive)
        breed_key = breed.strip() if breed and breed.strip() else "Sin raza registrada"
        result.by_breed.setdefault(breed_key, Matrix()).add(vet_positive, ai_positive)
    return result
