import numpy as np

from app.inference.base import PreprocessingSpec


class StubInference:
    """Devuelve siempre la misma probabilidad. Permite desarrollar api/ y app/ mientras
    ml/ entrena el modelo real. Prohibido en producción (ver Settings)."""

    def __init__(self, probability: float, spec: PreprocessingSpec | None = None) -> None:
        if not 0.0 <= probability <= 1.0:
            raise ValueError("La probabilidad del stub debe estar entre 0 y 1")
        self._probability = probability
        self._spec = spec or PreprocessingSpec()

    @property
    def version(self) -> str:
        return "stub-1"

    @property
    def preprocessing(self) -> PreprocessingSpec:
        return self._spec

    def predict(self, batch: np.ndarray) -> float:
        size = self._spec.input_size
        if batch.shape != (1, size, size, 3):
            raise ValueError(f"Se esperaba un lote (1, {size}, {size}, 3) y llegó {batch.shape}")
        return self._probability
