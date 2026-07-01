"""
FarmEye Guard v1.0 — 命令控制 API 单元测试

覆盖用例 #23-#28：
  #23 test_send_command_online        设备在线 → 200, status=sent
  #24 test_send_command_offline       设备离线 → 200, code=1003
  #25 test_send_command_missing_field 缺少 command → 422
  #26 test_logs_source_filter         source=auto 过滤
  #27 test_logs_time_range            时间范围筛选
  #28 test_logs_pagination            分页查询

测试策略：Mock command_service 层函数。
"""
from datetime import datetime
from unittest.mock import patch

import pytest


def _make_control_log(
    log_id: int = 1,
    device_id: str = "dev_001",
    command: str = "relay_on",
    source: str = "auto",
):
    """构建模拟控制日志对象。"""
    return type(
        "MockControlLog",
        (),
        {
            "id": log_id,
            "device_id": device_id,
            "command_id": f"cmd_{log_id:03d}",
            "timestamp": datetime(2025, 1, 1, 12, 0, 0),
            "command": command,
            "source": source,
            "operator": None,
            "result_code": None,
            "result_msg": None,
            "created_at": datetime(2025, 1, 1, 12, 0, 0),
        },
    )()


# =========================================================================
# 命令下发
# =========================================================================


@pytest.mark.asyncio
async def test_send_command_online(async_client):
    """
    用例 #23：设备在线时下发命令。

    预期：
      - HTTP 200
      - status = "sent"
      - command_id 存在
    """
    mock_result = {
        "command_id": "cmd_mock_abc123",
        "device_id": "dev_001",
        "command": "relay_on",
        "status": "sent",
    }

    with patch("app.api.v1.command.create_command") as mock_create:
        mock_create.return_value = mock_result

        response = await async_client.post(
            "/api/v1/command/send",
            json={"device_id": "dev_001", "command": "relay_on"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["code"] == 0
        assert data["data"]["status"] == "sent"
        assert "command_id" in data["data"]


@pytest.mark.asyncio
async def test_send_command_offline(async_client):
    """
    用例 #24：设备离线时下发命令。

    预期：
      - HTTP 200
      - code = 1003
      - status = "offline"
    """
    mock_result = {"status": "offline", "code": 1003}

    with patch("app.api.v1.command.create_command") as mock_create:
        mock_create.return_value = mock_result

        response = await async_client.post(
            "/api/v1/command/send",
            json={"device_id": "dev_offline", "command": "relay_on"},
        )

        assert response.status_code == 200
        data = response.json()
        # 注意：端点返回 code=0 始终，实际状态在 data 内
        assert data["data"]["status"] == "offline"
        assert data["data"]["code"] == 1003


@pytest.mark.asyncio
async def test_send_command_missing_field(async_client):
    """
    用例 #25：缺少必需字段 command。

    预期：HTTP 422
    """
    response = await async_client.post(
        "/api/v1/command/send",
        json={"device_id": "dev_001"},  # 缺少 command
    )
    assert response.status_code == 422


# =========================================================================
# 控制日志查询
# =========================================================================


@pytest.mark.asyncio
async def test_logs_source_filter(async_client):
    """
    用例 #26：source=auto 过滤查询控制日志。

    预期：仅返回 source=auto 的记录。
    """
    logs = [_make_control_log(source="auto")]

    with patch("app.api.v1.command.get_command_logs") as mock_get:
        mock_get.return_value = (logs, 1)

        response = await async_client.get(
            "/api/v1/command/logs?source=auto"
        )

        assert response.status_code == 200
        data = response.json()
        assert data["code"] == 0
        assert len(data["data"]["records"]) == 1
        assert data["data"]["records"][0]["source"] == "auto"


@pytest.mark.asyncio
async def test_logs_time_range(async_client):
    """
    用例 #27：时间范围筛选查询控制日志。

    预期：返回时间范围内的记录。
    """
    logs = [_make_control_log()]

    with patch("app.api.v1.command.get_command_logs") as mock_get:
        mock_get.return_value = (logs, 1)

        response = await async_client.get(
            "/api/v1/command/logs"
            "?start=2025-01-01T00:00:00Z&end=2025-01-31T00:00:00Z"
        )

        assert response.status_code == 200
        data = response.json()
        assert data["code"] == 0
        assert len(data["data"]["records"]) == 1


@pytest.mark.asyncio
async def test_logs_pagination(async_client):
    """
    用例 #28：分页查询控制日志。

    page=1, page_size=20，预期返回 pagination 元数据。
    """
    logs = [_make_control_log() for _ in range(20)]

    with patch("app.api.v1.command.get_command_logs") as mock_get:
        mock_get.return_value = (logs, 50)

        response = await async_client.get(
            "/api/v1/command/logs?page=1&page_size=20"
        )

        assert response.status_code == 200
        data = response.json()
        assert data["code"] == 0
        assert len(data["data"]["records"]) == 20
        assert data["data"]["pagination"]["total"] == 50
        assert data["data"]["pagination"]["page"] == 1
        assert data["data"]["pagination"]["page_size"] == 20
