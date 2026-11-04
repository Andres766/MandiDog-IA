from typing import Literal

from pydantic import BaseModel


class HealthOut(BaseModel):
    status: Literal["ok", "degraded"]
    version: str
    environment: str
    analysis_provider: Literal["aiforpet"]
    database: Literal["ok", "error"]
