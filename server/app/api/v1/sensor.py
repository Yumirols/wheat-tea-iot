"""
FarmEye Guard v1.0 — 传感器数据查询端点

提供传感器最新数据、历史数据和日聚合数据的 REST 查询接口。
所有端点使用 API Key 认证。
"""
from datetime import date, datetime
from typing import Any, Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api import deps
from app.db.session import get_db
from app.schemas.sensor import SensorSnapshotRead, SensorDailyAggregationRead
from app.services.sensor_service import (
    get_latest_snapshots,
    get_sensor_history,
    get_daily_aggregation,
)

router = APIRouter(dependencies=[Depends(deps.verify_api_key)])


@router.get("/sensor/latest")
async def get_latest_sensor_data(
    device_id: Optional[str] = None,
    db: Session = Depends(get_db),
) -> dict:
    """
    查询最新传感器数据。

    - 指定 device_id：返回该设备最新一条 sensor_snapshot 记录
    - 不指定 device_id：返回所有设备的最新记录（每个设备一条）
    """
    snapshots = get_latest_snapshots(db, device_id)

    data: dict[str, Any] | list[dict[str, Any]] | None
    if device_id:
        data = (
            SensorSnapshotRead.model_validate(snapshots[0]).model_dump()
            if snapshots
            else None
        )
    else:
        data = [
            SensorSnapshotRead.model_validate(s).model_dump()
            for s in snapshots
        ]

    return {"code": 0, "message": "success", "data": data}


@router.get("/sensor/history")
async def get_sensor_history_endpoint(
    device_id: str,
    start: Optional[datetime] = None,
    end: Optional[datetime] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
) -> dict:
    """
    查询历史传感器数据。

    支持按时间范围筛选和分页查询。page_size 自动截断至最大 100。
    """
    page_size = min(page_size, 100)

    records, total = get_sensor_history(db, device_id, start, end, page, page_size)

    return {
        "code": 0,
        "message": "success",
        "data": {
            "pagination": {
                "total": total,
                "page": page,
                "page_size": page_size,
            },
            "records": [
                SensorSnapshotRead.model_validate(r).model_dump()
                for r in records
            ],
        },
    }


@router.get("/sensor/daily")
async def get_sensor_daily_endpoint(
    device_id: str,
    start: date,
    end: date,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
) -> dict:
    """
    查询日聚合数据。

    查询 sensor_daily_aggregation 表，支持日期范围筛选和分页。
    page_size 自动截断至最大 100。
    """
    page_size = min(page_size, 100)

    records, total = get_daily_aggregation(db, device_id, start, end, page, page_size)

    return {
        "code": 0,
        "message": "success",
        "data": {
            "pagination": {
                "total": total,
                "page": page,
                "page_size": page_size,
            },
            "records": [
                SensorDailyAggregationRead.model_validate(r).model_dump()
                for r in records
            ],
        },
    }
