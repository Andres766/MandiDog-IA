from dataclasses import dataclass
from typing import Literal, Protocol

import numpy as np

# unit: [0, 1] · mobilenet_v2: [-1, 1] · resnet50: BGR con resta de medias (caffe)
Normalization = Literal["unit", "mobilenet_v2", "resnet50"]


@dataclass(frozen=True)
class PreprocessingSpec:
    input_size: int = 224
    normalization: Normalization = "mobilenet_v2"


class InferenceBackend(Protocol):
    """Contrato del modelo. La API no sabe si detrás hay un stub o Keras."""

    @property
    def version(self) -> str: ...

    @property
    def preprocessing(self) -> PreprocessingSpec: ...

    def predict(self, batch: np.ndarray) -> float:
        """Recibe un lote (1, alto, ancho, 3) ya normalizado y devuelve p(con_signos)."""
        ...
