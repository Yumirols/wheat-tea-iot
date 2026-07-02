"""
FarmEye Guard v1.0 — 设备列表 API 单元测试

覆盖用例 #17：
  - #17: GET /api/v1/device/list → 200，返回设备列表含在线状态

设备列表端点直接在路由函数中查询 DB（未经过 Service 层），因此直接配置
mock_db_session 的链式调用返回值。
"""
from datetime import datetime

import pytest


def _make_mock_device(
    device_id: str = "test_dev_001",
    device_name: str = "Test Sensor",
    online: bool = True,
):
    """构建一个简单的类对象，用于 DeviceRead.model_validate。"""
    return type(
        "MockDevice",
        (),
        {
            "id": 1,
            "device_id": device_id,
            "device_name": device_name,
            "mac_addr": "AA:BB:CC:DD:EE:FF",
            "ip_addr": "192.168.1.100",
            "registered_at": datetime(2025, 1, 1, 12, 0, 0),
            "last_seen": datetime(2025, 1, 1, 12, 0, 0),
            "online": online,
            "created_at": datetime(2025, 1, 1, 12, 0, 0),
        },
    )()


@pytest.mark.asyncio
async def test_device_list(async_client, mock_db_session):
    """
    用例 #17：获取设备列表。

    预期：
      - HTTP 200
      - code = 0
      - data 为设备列表，每项含 device_id / device_name / online 等字段
    """
    mock_devices = [
        _make_mock_device(device_id="dev_001", device_name="Sensor Alpha"),
        _make_mock_device(device_id="dev_002", device_name="Sensor Beta", online=False),
    ]
    mock_db_session.query.return_value.order_by.return_value.all.return_value = (
        mock_devices
    )

    response = await async_client.get("/api/v1/device/list")

    assert response.status_code == 200
    data = response.json()
    assert data["code"] == 0
    assert len(data["data"]) == 2
    assert data["data"][0]["device_id"] == "dev_001"
    assert data["data"][0]["online"] is True
    assert data["data"][1]["device_id"] == "dev_002"
    assert data["data"][1]["online"] is False
