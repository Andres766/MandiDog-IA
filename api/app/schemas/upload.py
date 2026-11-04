from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class SignUploadIn(BaseModel):
    content_type: Literal["image/jpeg", "image/png"]
    content_length: int = Field(gt=0, description="Tamaño exacto en bytes del archivo a subir")


class SignUploadOut(BaseModel):
    upload_url: str
    object_key: str
    expires_at: datetime
    method: Literal["PUT"] = "PUT"
    headers: dict[str, str] = Field(
        description="Cabeceras que la app debe enviar en el PUT (forman parte de la firma)"
    )
