"""
FarmEye Guard v1.0 — IoTDA Webhook 接收端点

接收华为 IoTDA 平台推送的设备属性上报、AI 识别结果和命令应答。
所有端点默认不加认证依赖（IoTDA 推送无法携带自定义 Header）。
"""
import logging
from datetime import datetime
from typing import Any

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.services.sensor_service import create_snapshot, ensure_device_exists
from app.models.disease import DiseaseRecord
from app.models.control import ControlLog

logger = logging.getLogger(__name__)

router = APIRouter()


def _parse_event_time(event_time_str: str | None) -> datetime:
    """
    解析 IoTDA 事件时间字符串。

    IoTDA 使用两种时间格式：
    - 标准 ISO 8601: 2025-01-01T12:00:00Z
    - IoTDA 紧凑格式: 20250101T120000Z
    """
    if not event_time_str:
        return datetime.utcnow()

    # 尝试标准 ISO 格式
    try:
        return datetime.fromisoformat(event_time_str.replace("Z", "+00:00"))
    except (ValueError, AttributeError):
        pass

    # 尝试 IoTDA 紧凑格式: YYYYMMDDTHHmmssZ
    try:
        return datetime.strptime(event_time_str, "%Y%m%dT%H%M%SZ")
    except (ValueError, AttributeError):
        return datetime.utcnow()


def _parse_notify_data(payload: dict[str, Any]) -> tuple[dict[str, Any] | None, dict[str, Any] | None]:
    """
    从 IoTDA payload 中提取 notify_data 和 header。

    IoTDA 标准推送格式：
    {
        "resource": "device.property",
        "event": "report",
        "event_time": "...",
        "notify_data": {
            "header": {"device_id": "..."},
            "body": {
                "services": [{"service_id": "...", "properties": {...}}]
            }
        }
    }
    """
    notify_data = payload.get("notify_data")
    if not notify_data:
        return None, None
    header = notify_data.get("header", {})
    return notify_data, header


def _find_service(services: list[dict[str, Any]], service_id: str) -> dict[str, Any] | None:
    """从 services 列表中查找指定 service_id 的 service 字典。"""
    for svc in services:
        if svc.get("service_id") == service_id:
            return svc
    return None


@router.post("/iotda/properties/report")
async def handle_properties_report(
    payload: dict[str, Any],
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    """
    接收 IoTDA 传感器属性上报。

    IoTDA 标准设备属性上报 payload 示例：
    ```
    {
      "resource": "device.property",
      "event": "report",
      "event_time": "20250101T120000Z",
      "notify_data": {
        "header": {"device_id": "dev_001"},
        "body": {
          "services": [{
            "service_id": "farmeye_env",
            "properties": {
              "temperature": 25.5,
              "humidity": 60.0,
              "light": 45000,
              "co2": 420,
              "soil_n": 12.5,
              "soil_p": 8.3,
              "soil_k": 15.7,
              "distance": 35,
              "rssi": -65,
              "ip_addr": "192.168.1.100",
              "mac_addr": "AA:BB:CC:DD:EE:FF",
              "alarm_flag": 0
            }
          }]
        }
      }
    }
    ```
    """
    notify_data, header = _parse_notify_data(payload)
    if not notify_data:
        raise HTTPException(status_code=422, detail="Missing notify_data")

    device_id = header.get("device_id")
    if not device_id:
        raise HTTPException(status_code=422, detail="Missing device_id in header")

    body = notify_data.get("body", {})
    services = body.get("services", [])

    service = _find_service(services, "farmeye_env")
    if not service:
        # 未知 service_id（非 farmeye_env）：忽略写入，仍返回 200
        logger.info("Unknown service_id for properties report, ignored")
        return {"code": 0, "message": "success"}

    properties = service.get("properties", {})
    event_time_str = payload.get("event_time")
    timestamp = _parse_event_time(event_time_str)

    try:
        snapshot = create_snapshot(
            db=db,
            device_id=device_id,
            properties=properties,
            timestamp=timestamp,
        )
        return {
            "code": 0,
            "message": "success",
            "data": {"id": snapshot.id},
        }
    except Exception as exc:
        # 幂等性：相同 device_id + timestamp 的重复写入由数据库 UNIQUE 索引拒绝，
        # 捕获异常后仍返回 200（IoTDA 重试场景）
        logger.warning(
            "Properties report idempotent handling for device=%s: %s",
            device_id,
            exc,
        )
        db.rollback()
        return {"code": 0, "message": "success"}


@router.post("/iotda/ai/report")
async def handle_ai_report(
    payload: dict[str, Any],
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    """
    接收 IoTDA AI 识别结果上报。

    AI 识别 payload 示例：
    ```
    {
      "resource": "device.message",
      "event": "report",
      "event_time": "20250101T120000Z",
      "notify_data": {
        "header": {"device_id": "dev_001"},
        "body": {
          "services": [{
            "service_id": "farmeye_ai",
            "properties": {
              "crop_type": "wheat",
              "disease_type": "powdery_mildew",
              "confidence": 0.95,
              "severity": "Moderate",
              "severity_code": 2
            }
          }]
        }
      }
    }
    ```
    """
    notify_data, header = _parse_notify_data(payload)
    if not notify_data:
        raise HTTPException(status_code=422, detail="Missing notify_data")

    device_id = header.get("device_id")
    if not device_id:
        raise HTTPException(status_code=422, detail="Missing device_id in header")

    body = notify_data.get("body", {})
    services = body.get("services", [])

    service = _find_service(services, "farmeye_ai")
    if not service:
        # 未知 service_id（非 farmeye_ai）：忽略写入，返回 200
        logger.info("Unknown service_id for AI report, ignored")
        return {"code": 0, "message": "success"}

    properties = service.get("properties", {})
    event_time_str = payload.get("event_time")
    timestamp = _parse_event_time(event_time_str)

    try:
        # 确保设备记录存在
        ensure_device_exists(db, device_id, properties.get("mac_addr"))

        record = DiseaseRecord(
            device_id=device_id,
            timestamp=timestamp,
            crop_type=properties.get("crop_type", "unknown"),
            disease_type=properties.get("disease_type", "unknown"),
            confidence=properties.get("confidence"),
            severity=properties.get("severity", "Unknown"),
            severity_code=properties.get("severity_code", 0),
        )
        db.add(record)
        db.commit()
        db.refresh(record)

        return {
            "code": 0,
            "message": "success",
            "data": {"id": record.id},
        }
    except Exception as exc:
        # 幂等性：相同 device_id + timestamp + disease_type 的重复写入由 UNIQUE 索引拒绝
        logger.warning(
            "AI report idempotent handling for device=%s: %s",
            device_id,
            exc,
        )
        db.rollback()
        return {"code": 0, "message": "success"}


@router.post("/iotda/cmd/response")
async def handle_command_response(
    payload: dict[str, Any],
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    """
    接收 IoTDA 命令应答上报。

    命令应答 payload 示例：
    ```
    {
      "notify_data": {
        "header": {"device_id": "dev_001"},
        "body": {
          "services": [{
            "service_id": "farmeye_env",
            "properties": {
              "command_id": "cmd_001",
              "result_code": 0,
              "result_msg": "success"
            }
          }]
        }
      }
    }
    ```
    """
    notify_data, header = _parse_notify_data(payload)
    if not notify_data:
        raise HTTPException(status_code=422, detail="Missing notify_data")

    device_id = header.get("device_id")
    if not device_id:
        raise HTTPException(status_code=422, detail="Missing device_id in header")

    body = notify_data.get("body", {})
    services = body.get("services", [])

    # 遍历 services 查找包含 command_id 的 properties
    command_id = None
    result_code = None
    result_msg = None

    for svc in services:
        props = svc.get("properties", {})
        if "command_id" in props:
            command_id = props.get("command_id")
            result_code = props.get("result_code")
            result_msg = props.get("result_msg")
            break

    if not command_id:
        logger.info("No command_id found in command response payload")
        return {"code": 0, "message": "success"}

    # 更新 control_logs 表中对应 command_id 的记录
    updated = db.query(ControlLog).filter(
        ControlLog.command_id == command_id,
    ).update(
        {
            "result_code": result_code,
            "result_msg": result_msg,
        },
    )
    db.commit()

    if updated == 0:
        # command_id 不存在于 control_logs，仅记录已消费
        logger.info(
            "Command response for unknown command_id=%s from device=%s, recorded as consumed",
            command_id,
            device_id,
        )

    return {"code": 0, "message": "success"}
