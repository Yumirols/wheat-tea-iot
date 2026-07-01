"""
FarmEye Guard v1.0 — 病虫害记录 Pydantic Schema

包含病虫害记录读取、病虫害统计数据响应。
"""
from datetime import datetime
from typing import Optional
from pydantic import BaseModel


class DiseaseRecordRead(BaseModel):
    """病虫害记录响应模型"""

    id: int
    device_id: str
    timestamp: datetime
    crop_type: str
    disease_type: str
    confidence: Optional[float] = None
    severity: str
    severity_code: int
    linkage_risk_level: Optional[str] = None
    linkage_detail: Optional[str] = None
    image_path: Optional[str] = None
    action_taken: Optional[str] = None
    created_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class DiseaseStatsResponse(BaseModel):
    """病虫害统计响应模型"""

    total_detections: int
    by_crop: dict[str, int]
    by_severity: dict[str, int]
    by_disease: dict[str, int]
