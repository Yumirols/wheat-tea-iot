"""
FarmEye Guard v1.0 — 病虫害业务逻辑层

提供病虫害记录查询、统计聚合和热力图数据等业务方法。
"""
import logging
from datetime import datetime
from typing import Optional

from sqlalchemy import func, and_
from sqlalchemy.orm import Session

from app.models.disease import DiseaseRecord

logger = logging.getLogger(__name__)


def get_disease_records(
    db: Session,
    device_id: Optional[str] = None,
    crop_type: Optional[str] = None,
    disease_type: Optional[str] = None,
    severity: Optional[str] = None,
    start: Optional[datetime] = None,
    end: Optional[datetime] = None,
    page: int = 1,
    page_size: int = 20,
) -> tuple[list[DiseaseRecord], int]:
    """
    分页查询病虫害记录，支持多条件筛选和时间范围过滤。

    支持的可选筛选条件：device_id、crop_type、disease_type、severity。
    支持 timestamp 时间范围过滤（start / end）。
    按 timestamp DESC 排序。

    返回 (records, total_count) 元组。
    """
    query = db.query(DiseaseRecord)

    if device_id:
        query = query.filter(DiseaseRecord.device_id == device_id)
    if crop_type:
        query = query.filter(DiseaseRecord.crop_type == crop_type)
    if disease_type:
        query = query.filter(DiseaseRecord.disease_type == disease_type)
    if severity:
        query = query.filter(DiseaseRecord.severity == severity)
    if start:
        query = query.filter(DiseaseRecord.timestamp >= start)
    if end:
        query = query.filter(DiseaseRecord.timestamp <= end)

    total_count = query.count()

    records = (
        query.order_by(DiseaseRecord.timestamp.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )

    return records, total_count


def get_disease_stats(
    db: Session,
    start: Optional[datetime] = None,
    end: Optional[datetime] = None,
) -> dict:
    """
    统计指定时间范围内的病虫害记录。

    构建共享过滤条件直接应用到每个分组聚合查询中，
    避免先物化 ID 再查询的低效模式。

    返回字典包含：
    - total_detections: 总记录数
    - by_crop: 按作物类型分组统计
    - by_severity: 按严重程度分组统计（Mild/Moderate/Severe）
    - by_disease: 按病害类型分组统计
    """
    # 构建共享过滤条件
    filters: list = []
    if start:
        filters.append(DiseaseRecord.timestamp >= start)
    if end:
        filters.append(DiseaseRecord.timestamp <= end)

    # 总记录数
    total_detections = (
        db.query(func.count(DiseaseRecord.id)).filter(*filters).scalar() or 0
    )

    if total_detections == 0:
        return {
            "total_detections": 0,
            "by_crop": {},
            "by_severity": {},
            "by_disease": {},
        }

    # 按作物类型分组统计
    crop_counts = dict(
        db.query(
            DiseaseRecord.crop_type,
            func.count(DiseaseRecord.id),
        )
        .filter(*filters)
        .group_by(DiseaseRecord.crop_type)
        .all()
    )

    # 按严重程度分组统计
    severity_counts: dict[str, int] = {}
    for row in (
        db.query(
            DiseaseRecord.severity,
            func.count(DiseaseRecord.id),
        )
        .filter(*filters)
        .group_by(DiseaseRecord.severity)
        .all()
    ):
        severity_counts[row[0]] = row[1]

    # 按病害类型分组统计
    disease_counts: dict[str, int] = {}
    for row in (
        db.query(
            DiseaseRecord.disease_type,
            func.count(DiseaseRecord.id),
        )
        .filter(*filters)
        .group_by(DiseaseRecord.disease_type)
        .all()
    ):
        disease_counts[row[0]] = row[1]

    return {
        "total_detections": total_detections,
        "by_crop": crop_counts,
        "by_severity": severity_counts,
        "by_disease": disease_counts,
    }


def get_heatmap_data(
    db: Session,
) -> dict:
    """
    返回病虫害热力图数据。

    返回字典包含：
    - heatmap_points: 每条记录含 device_id、disease_type、severity、timestamp、crop_type
    - summary: 活跃病虫害类型数、受影响设备数等统计
    """
    records = db.query(DiseaseRecord).order_by(DiseaseRecord.timestamp.desc()).all()

    heatmap_points = [
        {
            "device_id": r.device_id,
            "disease_type": r.disease_type,
            "severity": r.severity,
            "timestamp": r.timestamp.isoformat() if r.timestamp else None,
            "crop_type": r.crop_type,
        }
        for r in records
    ]

    # 统计摘要
    disease_types = set(r.disease_type for r in records)
    device_ids = set(r.device_id for r in records)

    summary = {
        "active_disease_types": len(disease_types),
        "affected_devices": len(device_ids),
        "total_records": len(records),
    }

    return {
        "heatmap_points": heatmap_points,
        "summary": summary,
    }
