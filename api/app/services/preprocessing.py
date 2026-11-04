"""Imagen → tensor de entrada del modelo.

Redimensiona directo a input_size×input_size (sin recorte), igual que el entrenamiento en
ml/, y normaliza según la arquitectura que declara el backend de inferencia.
"""

import numpy as np
from PIL import Image

from app.inference.base import PreprocessingSpec

# Medias BGR de ImageNet que usa keras.applications.resnet50.preprocess_input (modo caffe)
_CAFFE_BGR_MEAN = np.array([103.939, 116.779, 123.68], dtype=np.float32)


def preprocess(image: Image.Image, spec: PreprocessingSpec) -> np.ndarray:
    size = (spec.input_size, spec.input_size)
    resized = image.convert("RGB").resize(size, Image.Resampling.BILINEAR)
    pixels = np.asarray(resized, dtype=np.float32)

    if spec.normalization == "unit":
        pixels = pixels / 255.0
    elif spec.normalization == "mobilenet_v2":
        pixels = pixels / 127.5 - 1.0
    elif spec.normalization == "resnet50":
        pixels = pixels[..., ::-1] - _CAFFE_BGR_MEAN
    else:
        raise ValueError(f"Normalización desconocida: {spec.normalization}")

    return np.ascontiguousarray(pixels[np.newaxis, ...], dtype=np.float32)
