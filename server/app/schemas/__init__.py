"""
FarmEye Guard v1.0 — Pydantic Schema 导出

统一导出所有 Schema 类，方便外部导入。
"""
from app.schemas.common import ResponseModel, PaginationParams, PaginationMeta
from app.schemas.sensor import SensorSnapshotRead, SensorHistoryResponse
from app.schemas.disease import DiseaseRecordRead, DiseaseStatsResponse
from app.schemas.command import CommandCreate, CommandRead, CommandResponse
from app.schemas.device import DeviceRead

__all__ = [
    "ResponseModel",
    "PaginationParams",
    "PaginationMeta",
    "SensorSnapshotRead",
    "SensorHistoryResponse",
    "DiseaseRecordRead",
    "DiseaseStatsResponse",
    "CommandCreate",
    "CommandRead",
    "CommandResponse",
    "DeviceRead",
]
