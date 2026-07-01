"""
FarmEye Guard v1.0 — 传感器业务逻辑层

提供传感器数据快照写入、设备注册确保、最新数据查询、
历史数据分页查询和日聚合数据查询等业务方法。
"""
import logging
from datetime import date, datetime
from typing import Optional

from sqlalchemy import func, and_
from sqlalchemy.orm import Session

from app.models.sensor import SensorSnapshot, SensorDailyAggregation
from app.models.control import Device

logger = logging.getLogger(__name__)


def create_snapshot(
    db: Session,
    device_id: str,
    properties: dict,
    timestamp: datetime,
) -> SensorSnapshot:
    """
    创建传感器数据快照。

    从 properties 字典中提取温湿度等环境参数，构造 SensorSnapshot 对象，
    同时确保设备记录存在。返回新创建的 SensorSnapshot 记录。
    """
    # 确保设备记录存在
    ensure_device_exists(db, device_id, properties.get("mac_addr"))

    snapshot = SensorSnapshot(
        device_id=device_id,
        timestamp=timestamp,
        temperature=properties.get("temperature"),
        humidity=properties.get("humidity"),
        light=properties.get("light"),
        co2=properties.get("co2"),
        soil_n=properties.get("soil_n"),
        soil_p=properties.get("soil_p"),
        soil_k=properties.get("soil_k"),
        distance=properties.get("distance"),
        rssi=properties.get("rssi"),
        ip_addr=properties.get("ip_addr"),
        mac_addr=properties.get("mac_addr"),
        alarm_flag=properties.get("alarm_flag"),
    )

    db.add(snapshot)
    db.commit()
    db.refresh(snapshot)

    return snapshot


def ensure_device_exists(
    db: Session,
    device_id: str,
    mac_addr: str | None = None,
) -> Device:
    """
    确保设备记录存在。

    - 检查 devices 表中是否存在该 device_id
    - 不存在则创建新 Device 记录（device_id, mac_addr, online=False）
    - 存在则更新 last_seen 为当前时间
    - 返回 Device 对象
    """
    device = db.query(Device).filter(Device.device_id == device_id).first()

    if not device:
        device = Device(
            device_id=device_id,
            mac_addr=mac_addr,
            online=False,
            last_seen=datetime.utcnow(),
        )
        db.add(device)
        db.commit()
        db.refresh(device)
        logger.info("Auto-registered new device: %s", device_id)
    else:
        device.last_seen = datetime.utcnow()
        db.commit()
        db.refresh(device)

    return device


def get_latest_snapshots(
    db: Session,
    device_id: str | None = None,
) -> list[SensorSnapshot]:
    """
    查询最新传感器数据。

    - 指定 device_id：返回该设备最新一条 sensor_snapshot 记录
    - 不指定 device_id：返回每个设备的最新一条记录
    """
    if device_id:
        # 查询指定设备的最新一条记录
        snapshot = (
            db.query(SensorSnapshot)
            .filter(SensorSnapshot.device_id == device_id)
            .order_by(SensorSnapshot.timestamp.desc())
            .first()
        )
        return [snapshot] if snapshot else []

    # 查询所有设备的最新记录
    # 使用子查询：先按 device_id 分组获取最大 timestamp
    subq = (
        db.query(
            SensorSnapshot.device_id,
            func.max(SensorSnapshot.timestamp).label("max_ts"),
        )
        .group_by(SensorSnapshot.device_id)
        .subquery()
    )

    snapshots = (
        db.query(SensorSnapshot)
        .join(
            subq,
            and_(
                SensorSnapshot.device_id == subq.c.device_id,
                SensorSnapshot.timestamp == subq.c.max_ts,
            ),
        )
        .order_by(SensorSnapshot.device_id)
        .all()
    )

    return snapshots


def get_sensor_history(
    db: Session,
    device_id: str,
    start: datetime | None,
    end: datetime | None,
    page: int,
    page_size: int,
) -> tuple[list[SensorSnapshot], int]:
    """
    分页查询传感器历史数据，支持时间范围筛选。

    返回 (records, total_count) 元组。
    """
    query = db.query(SensorSnapshot).filter(
        SensorSnapshot.device_id == device_id,
    )

    if start:
        query = query.filter(SensorSnapshot.timestamp >= start)
    if end:
        query = query.filter(SensorSnapshot.timestamp <= end)

    # 先获取总数
    total_count = query.count()

    # 分页查询
    records = (
        query.order_by(SensorSnapshot.timestamp.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )

    return records, total_count


def get_daily_aggregation(
    db: Session,
    device_id: str,
    start: date,
    end: date,
    page: int,
    page_size: int,
) -> tuple[list[SensorDailyAggregation], int]:
    """
    分页查询日聚合数据，支持日期范围筛选。

    返回 (records, total_count) 元组。
    """
    query = db.query(SensorDailyAggregation).filter(
        SensorDailyAggregation.device_id == device_id,
        SensorDailyAggregation.agg_date >= start,
        SensorDailyAggregation.agg_date <= end,
    )

    total_count = query.count()

    records = (
        query.order_by(SensorDailyAggregation.agg_date.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )

    return records, total_count
