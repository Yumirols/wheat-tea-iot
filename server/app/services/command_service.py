"""
FarmEye Guard v1.0 — 命令控制业务逻辑层

提供命令创建下发和控制日志分页查询等业务方法。
"""
import logging
from datetime import datetime
from typing import Optional

from sqlalchemy.orm import Session

from app.models.control import ControlLog, Device
from app.services import iotda_client

logger = logging.getLogger(__name__)


def create_command(
    db: Session,
    device_id: str,
    command: str,
    source: str,
    operator: Optional[str] = None,
) -> dict:
    """
    创建并下发设备命令。

    1. 检查设备是否在线（Device.online == True）
    2. 设备在线：调用 iotda_client.send_command 下发命令
    3. 在 control_logs 表中创建 ControlLog 记录
    4. 返回命令下发结果字典

    设备离线时返回 {"status": "offline", "code": 1003}。
    """
    # 检查设备在线状态
    device = db.query(Device).filter(Device.device_id == device_id).first()

    if not device or not device.online:
        logger.info("Device %s is offline, command rejected", device_id)
        return {"status": "offline", "code": 1003}

    # 下发命令
    try:
        iotda_response = iotda_client.send_command(device_id, command)
        command_id = iotda_response.get("command_id")
    except Exception as exc:
        logger.error("Failed to send command to device %s: %s", device_id, exc)
        return {"status": "failed", "code": 1002, "message": str(exc)}

    # 创建控制日志
    log = ControlLog(
        device_id=device_id,
        command_id=command_id,
        command=command,
        source=source,
        operator=operator,
    )
    db.add(log)
    db.commit()
    db.refresh(log)

    logger.info(
        "Command sent to device=%s command=%s command_id=%s",
        device_id,
        command,
        command_id,
    )

    return {
        "command_id": command_id,
        "device_id": device_id,
        "command": command,
        "status": "sent",
    }


def get_command_logs(
    db: Session,
    device_id: Optional[str] = None,
    source: Optional[str] = None,
    start: Optional[datetime] = None,
    end: Optional[datetime] = None,
    page: int = 1,
    page_size: int = 20,
) -> tuple[list[ControlLog], int]:
    """
    分页查询控制日志，支持筛选和时间范围过滤。

    支持的可选筛选条件：device_id、source。
    支持 timestamp 时间范围过滤（start / end）。
    按 timestamp DESC 排序。

    返回 (records, total_count) 元组。
    """
    query = db.query(ControlLog)

    if device_id:
        query = query.filter(ControlLog.device_id == device_id)
    if source:
        query = query.filter(ControlLog.source == source)
    if start:
        query = query.filter(ControlLog.timestamp >= start)
    if end:
        query = query.filter(ControlLog.timestamp <= end)

    total_count = query.count()

    records = (
        query.order_by(ControlLog.timestamp.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )

    return records, total_count
