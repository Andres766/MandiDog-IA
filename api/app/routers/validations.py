import uuid
from typing import Annotated

from fastapi import APIRouter, Query, status

from app.deps import CurrentVet, DbSession
from app.schemas.validation import (
    MatrixOut,
    PendingCaseOut,
    RevealOut,
    SummaryOut,
    ValidationIn,
)
from app.services import validation_service as svc

router = APIRouter(prefix="/api/v1", tags=["validación clínica"])

CRITERION = (
    "Referencia: valoración del veterinario. La IA 've signos' cuando el estado de "
    "AI for Pet es CAUTION o WARNING. Los casos no evaluables no entran en la matriz."
)


@router.get("/validations/pending", response_model=list[PendingCaseOut])
def pending(
    vet: CurrentVet,
    db: DbSession,
    limit: Annotated[int, Query(ge=1, le=100)] = 30,
) -> list[PendingCaseOut]:
    """Casos que este veterinario aún no valoró, del más antiguo al más reciente.
    No incluyen el resultado de la IA: la validación es ciega."""
    return [PendingCaseOut(**vars(case)) for case in svc.pending_cases(db, vet, limit=limit)]


@router.post(
    "/analyses/{analysis_id}/validation",
    response_model=RevealOut,
    status_code=status.HTTP_201_CREATED,
)
def validate(
    analysis_id: uuid.UUID, body: ValidationIn, vet: CurrentVet, db: DbSession
) -> RevealOut:
    """Registra la valoración del veterinario y, solo entonces, revela el resultado de la IA."""
    reveal = svc.submit_validation(db, vet, analysis_id, body.vet_assessment, body.notes)
    return RevealOut(
        validation_id=reveal.validation.id,
        vet_assessment=reveal.validation.vet_assessment,
        ai_risk_level=reveal.analysis.risk_level,
        ai_provider_status=reveal.analysis.provider_status,
        ai_sees_signs=svc.ai_sees_signs(reveal.analysis),
        agreement=reveal.agreement,
    )


@router.get("/validations/summary", response_model=SummaryOut)
def summary(_: CurrentVet, db: DbSession) -> SummaryOut:
    """Concordancia entre veterinarios e IA: total, por biotipo cefálico y por raza."""
    result = svc.summary(db)

    def out(matrix: svc.Matrix) -> MatrixOut:
        return MatrixOut(**matrix.as_dict())

    return SummaryOut(
        validations=result.validations,
        not_evaluable=result.not_evaluable,
        criterion=CRITERION,
        overall=out(result.overall),
        by_cephalic_group={k: out(v) for k, v in sorted(result.by_cephalic_group.items())},
        by_breed={k: out(v) for k, v in sorted(result.by_breed.items())},
    )
