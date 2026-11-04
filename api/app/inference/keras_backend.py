"""Backend real con Keras. Se completa en la etapa 2 (ml/).

Espera junto al modelo un JSON de metadatos con el mismo nombre que genera ml/:
    artifacts/mandidog_mobilenetv2_v1.keras
    artifacts/mandidog_mobilenetv2_v1.json  -> {"version", "input_size", "normalization"}
"""

import json
from pathlib import Path

import numpy as np

from app.inference.base import PreprocessingSpec


class KerasInference:
    def __init__(self, model_path: str) -> None:
        try:
            import tensorflow as tf
        except ImportError as exc:
            raise RuntimeError(
                "INFERENCE_BACKEND=keras requiere TensorFlow instalado en la imagen de la API"
            ) from exc

        path = Path(model_path)
        meta = json.loads(path.with_suffix(".json").read_text(encoding="utf-8"))
        self._version = str(meta["version"])
        self._spec = PreprocessingSpec(
            input_size=int(meta["input_size"]), normalization=meta["normalization"]
        )
        self._model = tf.keras.models.load_model(path, compile=False)

    @property
    def version(self) -> str:
        return self._version

    @property
    def preprocessing(self) -> PreprocessingSpec:
        return self._spec

    def predict(self, batch: np.ndarray) -> float:
        output = self._model(batch, training=False)
        return float(np.asarray(output).reshape(-1)[0])
