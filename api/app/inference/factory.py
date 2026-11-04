from app.core.config import Settings
from app.inference.base import InferenceBackend
from app.inference.stub import StubInference


def build_inference(settings: Settings) -> InferenceBackend:
    if settings.inference_backend == "stub":
        return StubInference(settings.inference_stub_probability)
    from app.inference.keras_backend import KerasInference

    assert settings.inference_model_path  # garantizado por Settings
    return KerasInference(settings.inference_model_path)
