"""Interpretación del resultado del SDK (sin BD)."""

import pytest

from app.core.errors import UnprocessableError
from app.models import RiskLevel
from app.services.aiforpet import VET_NOTICE, parse_tooth_scan, recommendation_for
from tests.helpers import OFFICIAL_TOOTH_RESULT, tooth_result


def parse(result):
    return parse_tooth_scan(result, raw_size=100)


def test_ejemplo_oficial():
    scan = parse(OFFICIAL_TOOTH_RESULT)
    assert scan.risk_level == RiskLevel.YELLOW
    assert scan.provider_status == "CAUTION"
    assert scan.sub_part == "TCENTER"
    assert [(f.code, f.status) for f in scan.findings] == [
        ("inflammation", "abnormal"),
        ("calculus", "normal"),
    ]


def _with_symptom(**symptom):
    result = tooth_result()
    result["response"]["symptoms"] = [{"code": "calculus", **symptom}]
    return result


@pytest.mark.parametrize(
    ("symptom", "expected"),
    [
        ({"abnormLevel": 0}, "normal"),
        ({"abnormLevel": 2}, "abnormal"),
        # Nivel negativo = no evaluado, aunque isAbnormal diga false.
        ({"abnormLevel": -1, "isAbnormal": False}, "unknown"),
        # abnormalLevel tiene prioridad sobre abnormLevel.
        ({"abnormLevel": 0, "abnormalLevel": 1}, "abnormal"),
        ({"resultLabel": "abnormal"}, "abnormal"),
        ({"resultLabel": "normal"}, "normal"),
        ({}, "unknown"),
    ],
    ids=[
        "nivel_0",
        "nivel_positivo",
        "nivel_negativo",
        "alias_abnormalLevel",
        "solo_etiqueta_anormal",
        "solo_etiqueta_normal",
        "sin_datos",
    ],
)
def test_estado_de_cada_hallazgo(symptom, expected):
    assert parse(_with_symptom(**symptom)).findings[0].status == expected


def test_codigo_desconocido_usa_el_nombre_del_sdk_o_el_codigo():
    result = tooth_result()
    result["response"]["symptoms"] = [
        {"code": "nuevo_hallazgo", "name": "New finding", "abnormLevel": 0},
        {"code": "otro_hallazgo", "abnormLevel": 0},
    ]
    names = [f.name for f in parse(result).findings]
    assert names == ["New finding", "otro_hallazgo"]


def test_codigos_repetidos_se_cuentan_una_vez():
    result = tooth_result()
    result["response"]["symptoms"] = [
        {"code": "calculus", "abnormLevel": 1},
        {"code": "calculus", "abnormLevel": 0},
    ]
    assert len(parse(result).findings) == 1


def test_sin_hallazgos_es_valido():
    result = tooth_result("NORMAL")
    result["response"]["symptoms"] = []
    scan = parse(result)
    assert scan.risk_level == RiskLevel.GREEN
    assert scan.findings == []


@pytest.mark.parametrize("created_at", [None, -5, 10**20])
def test_fecha_de_analisis_ausente_o_absurda(created_at):
    assert parse(tooth_result(createdAt=created_at)).analyzed_at is None


def test_resultado_invalido_trae_detalles():
    with pytest.raises(UnprocessableError) as exc_info:
        parse(tooth_result(part="EYE"))
    assert exc_info.value.code == "scan_result_invalid"
    assert any(d["field"] == "part" for d in exc_info.value.details)


@pytest.mark.parametrize("level", list(RiskLevel))
def test_toda_recomendacion_incluye_el_aviso_veterinario(level):
    assert recommendation_for(level).endswith(VET_NOTICE)
