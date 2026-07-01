"""
FarmEye Guard v1.0 — 设备响应 Pydantic Schema

包含设备信息的响应模型。
"""
from datetime import datetime
from typing import Optional
from pydantic import BaseModel


class DeviceRead(BaseModel):
    """设备信息响应模型"""

    id: int
    device_id: str
    device_name: Optional[str] = None
    mac_addr: Optional[str] = None
    ip_addr: Optional[str] = None
    registered_at: Optional[datetime] = None
    last_seen: Optional[datetime] = None
    online: bool
    created_at: Optional[datetime] = None

    model_config = {"from_attributes": True}
