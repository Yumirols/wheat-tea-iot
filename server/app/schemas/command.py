"""
FarmEye Guard v1.0 — 命令控制 Pydantic Schema

包含命令创建请求、命令读取响应和命令结果响应。
"""
from datetime import datetime
from typing import Optional
from pydantic import BaseModel


class CommandCreate(BaseModel):
    """创建命令请求模型"""

    device_id: str
    command: str
    source: str = "manual_app"
    operator: Optional[str] = None


class CommandRead(BaseModel):
    """命令记录响应模型"""

    id: int
    device_id: str
    command_id: Optional[str] = None
    timestamp: datetime
    command: str
    source: str
    operator: Optional[str] = None
    result_code: Optional[int] = None
    result_msg: Optional[str] = None
    created_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class CommandResponse(BaseModel):
    """命令下发响应模型"""

    command_id: Optional[str] = None
    device_id: str
    command: str
    status: str  # sent / failed / offline
