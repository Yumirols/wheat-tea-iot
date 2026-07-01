"""
FarmEye Guard v1.0 — 命令控制端点

提供命令下发和控制日志查询的 REST 接口。
所有端点使用 API Key 认证。
"""
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api import deps
from app.db.session import get_db
from app.schemas.command import CommandCreate, CommandRead
from app.services.command_service import create_command, get_command_logs

router = APIRouter(dependencies=[Depends(deps.verify_api_key)])


@router.post("/command/send")
async def send_command(
    cmd: CommandCreate,
    db: Session = Depends(get_db),
) -> dict:
    """
    下发设备命令。

    接收命令创建请求，检查设备在线状态，调用 IoTDA 下发命令，
    记录控制日志。设备离线时返回 code 1003。
    """
    result = create_command(
        db,
        device_id=cmd.device_id,
        command=cmd.command,
        source=cmd.source,
        operator=cmd.operator,
    )

    return {
        "code": 0,
        "message": "success",
        "data": result,
    }


@router.get("/command/logs")
async def list_command_logs(
    device_id: Optional[str] = None,
    source: Optional[str] = None,
    start: Optional[datetime] = None,
    end: Optional[datetime] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
) -> dict:
    """
    查询控制日志列表。

    支持 device_id、source 筛选，支持 timestamp 时间范围筛选和分页查询。
    """
    records, total = get_command_logs(
        db,
        device_id=device_id,
        source=source,
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
                CommandRead.model_validate(r).model_dump()
                for r in records
            ],
        },
    }
