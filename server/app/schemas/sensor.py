"""
FarmEye Guard v1.0 — 传感器数据 Pydantic Schema

包含传感器快照读取和传感器历史数据响应。
"""
from datetime import datetime
from typing import Optional
from pydantic import BaseModel

from app.schemas.common import PaginationMeta


class SensorSnapshotRead(BaseModel):
    """传感器快照响应模型"""

    id: int
    device_id: str
    mac_addr: Optional[str] = None
    timestamp: datetime
    temperature: Optional[float] = None
    humidity: Optional[float] = None
    light: Optional[int] = None
    co2: Optional[int] = None
    soil_n: Optional[float] = None
    soil_p: Optional[float] = None
    soil_k: Optional[float] = None
    distance: Optional[int] = None
    rssi: Optional[int] = None
    ip_addr: Optional[str] = None
    alarm_flag: Optional[int] = None
    created_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class SensorHistoryResponse(BaseModel):
    """传感器历史数据响应模型"""

    pagination: PaginationMeta
    records: list[SensorSnapshotRead]
