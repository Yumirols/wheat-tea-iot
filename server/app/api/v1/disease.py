"""
FarmEye Guard v1.0 — 病虫害记录查询端点

提供病虫害记录列表（多条件筛选）、统计聚合和热力图数据的 REST 查询接口。
所有端点使用 API Key 认证。
"""
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api import deps
from app.db.session import get_db
from app.schemas.disease import DiseaseRecordRead
from app.services.disease_service import (
    get_disease_records,
    get_disease_stats,
    get_heatmap_data,
)

router = APIRouter(dependencies=[Depends(deps.verify_api_key)])


@router.get("/disease/list")
async def list_disease_records(
    device_id: Optional[str] = None,
    crop_type: Optional[str] = None,
    disease_type: Optional[str] = None,
    severity: Optional[str] = None,
    start: Optional[datetime] = None,
    end: Optional[datetime] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
) -> dict:
    """
    查询病虫害记录列表。

    支持 device_id、crop_type、disease_type、severity 筛选，
    支持 timestamp 时间范围筛选和分页查询。
    """
    records, total = get_disease_records(
        db,
        device_id=device_id,
        crop_type=crop_type,
        disease_type=disease_type,
        severity=severity,
        start=start,
        end=end,
        page=page,
        page_size=page_size,
    )

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
                DiseaseRecordRead.model_validate(r).model_dump()
                for r in records
            ],
        },
    }


@router.get("/disease/stats")
async def disease_statistics(
    start: Optional[datetime] = None,
    end: Optional[datetime] = None,
    db: Session = Depends(get_db),
) -> dict:
    """
    查询病虫害统计信息。

    支持可选的时间范围筛选，返回按作物类型、严重程度和病害类型
    分组的统计数据。
    """
    stats = get_disease_stats(db, start=start, end=end)

    return {
        "code": 0,
        "message": "success",
        "data": stats,
    }


@router.get("/disease/heatmap")
async def disease_heatmap(
    db: Session = Depends(get_db),
) -> dict:
    """
    查询病虫害热力图数据。

    返回所有病虫害记录的热力图点和摘要统计信息。
    """
    data = get_heatmap_data(db)

    return {
        "code": 0,
        "message": "success",
        "data": data,
    }
