"""
FarmEye Guard v1.0 — ORM 模型导出

统一导出所有模型，便于 Alembic 自动发现迁移目标和外部导入。
"""
from app.models.sensor import SensorSnapshot, SensorDailyAggregation
from app.models.disease import DiseaseRecord
from app.models.control import ControlLog, Device

__all__ = [
    "SensorSnapshot",
    "SensorDailyAggregation",
    "DiseaseRecord",
    "ControlLog",
    "Device",
]
