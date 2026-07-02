"""
FarmEye Guard v1.0 — 设备列表查询端点

提供设备列表查询的 REST 查询接口。
所有端点使用 API Key 认证。
"""
from typing import Optional

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api import deps
from app.db.session import get_db
from app.models.control import Device
from app.schemas.device import DeviceRead

router = APIRouter(dependencies=[Depends(deps.verify_api_key)])


@router.get("/device/list")
async def list_devices(
    device_id: Optional[str] = None,
    db: Session = Depends(get_db),
) -> dict:
    """
    查询设备列表。

    - 指定 device_id：返回该设备信息
    - 不指定 device_id：返回所有设备记录
    结果按 last_seen DESC NULLS LAST 排序。
    """
    query = db.query(Device)

    if device_id:
        query = query.filter(Device.device_id == device_id)

    devices = query.order_by(Device.last_seen.desc().nullslast()).all()

    data = [
        DeviceRead.model_validate(d).model_dump()
        for d in devices
    ]

    return {"code": 0, "message": "success", "data": data}
