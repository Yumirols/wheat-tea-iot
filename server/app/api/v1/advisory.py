"""
FarmEye Guard v1.0 — 防治建议 API 端点

提供环境-病虫害联动分析与防治建议查询的 REST 接口。
所有端点使用 API Key 认证。

设计参考：
  - docs/1_system_architecture.md §2.4 决策规则矩阵
  - docs/1_system_architecture.md §4.6.1 防治建议响应格式
"""
from datetime import datetime
from decimal import Decimal
from typing import Optional

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.api import deps
from app.db.session import get_db
from app.services.advisory_service import get_advisory

router = APIRouter(dependencies=[Depends(deps.verify_api_key)])


# ---------------------------------------------------------------------------
# Pydantic Schema
# ---------------------------------------------------------------------------

class LatestDetection(BaseModel):
    """最新病虫害检测信息"""
    crop_type: str
    disease_type: str
    severity: str
    severity_code: int
    confidence: Optional[float] = None
    timestamp: datetime

    model_config = {"from_attributes": True}


class CurrentEnv(BaseModel):
    """当前环境信息"""
    temperature: Optional[float] = None
    humidity: Optional[float] = None
    light: Optional[int] = None
    co2: Optional[int] = None


class EnvDiseaseLinkage(BaseModel):
    """环境-病虫害联动分析结果"""
    risk_level: str
    matched_conditions: list[str]
    recommendation: str


class AdvisoryAction(BaseModel):
    """防治建议"""
    action: str
    description: str
    auto_action_triggered: bool
    auto_action: Optional[str] = None


class AdvisoryResponseData(BaseModel):
    """防治建议 API 响应 data 字段"""
    latest_detection: Optional[LatestDetection] = None
    current_env: Optional[CurrentEnv] = None
    env_disease_linkage: Optional[EnvDiseaseLinkage] = None
    advisory: Optional[AdvisoryAction] = None


# ---------------------------------------------------------------------------
# API Endpoints
# ---------------------------------------------------------------------------

@router.get("/advisory")
async def get_advisory_endpoint(
    device_id: Optional[str] = Query(None, description="设备 ID"),
    start: Optional[datetime] = Query(
        None, description="起始时间 (ISO 8601)"
    ),
    end: Optional[datetime] = Query(
        None, description="结束时间 (ISO 8601)"
    ),
    window_minutes: Optional[int] = Query(
        None, ge=1, description="窗口分钟数，默认 60"
    ),
    db: Session = Depends(get_db),
) -> dict:
    """
    获取防治建议。

    根据时间窗口内的 AI 识别结果和环境数据，返回病虫害联动分析与防治建议。
    支持 device_id 筛选和自定义时间窗口。
    时间窗口内无检测记录时返回空结构（code=0, data 内各字段为 null）。
    """
    result = get_advisory(
        db,
        device_id=device_id,
        start=start,
        end=end,
        window_minutes=window_minutes,
    )

    return {
        "code": 0,
        "message": "success",
        "data": result,
    }
