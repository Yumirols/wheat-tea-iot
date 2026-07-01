"""
FarmEye Guard v1.0 — 健康检查 API 单元测试

覆盖用例 #39-#40：
  - #39: GET /api/v1/health，DB 正常 → 200, status=healthy
  - #40: GET /api/v1/health，DB 异常 → 503, status=degraded

健康检查端点直接使用 SessionLocal()（非依赖注入），测试时需 patch。
"""
from unittest.mock import MagicMock, patch

import pytest


@pytest.mark.asyncio
async def test_health_healthy(async_client):
    """
    用例 #39：健康检查 — 数据库正常。

    预期：
      - HTTP 200
      - JSON body 包含 "status": "healthy"
      - "db_connected": true
    """
    with patch("app.main.SessionLocal") as mock_session_local:
        mock_session = MagicMock()
        mock_session_local.return_value = mock_session

        # 模拟 execute + commit 均正常
        mock_session.execute.return_value = None
        mock_session.commit.return_value = None

        response = await async_client.get("/api/v1/health")

        assert response.status_code == 200
        data = response.json()
        assert data["code"] == 0
        assert data["data"]["status"] == "healthy"
        assert data["data"]["db_connected"] is True
        assert "uptime_seconds" in data["data"]
        assert data["data"]["version"] is not None


@pytest.mark.asyncio
async def test_health_degraded(async_client):
    """
    用例 #40：健康检查 — 数据库异常。

    预期：
      - HTTP 503
      - JSON body 包含 "status": "degraded"
      - "db_connected": false
    """
    with patch("app.main.SessionLocal") as mock_session_local:
        mock_session = MagicMock()
        mock_session_local.return_value = mock_session

        # 模拟 execute 抛出异常（DB 连接失败）
        mock_session.execute.side_effect = Exception("Connection refused")

        response = await async_client.get("/api/v1/health")

        assert response.status_code == 503
        data = response.json()
        assert data["code"] == 0
        assert data["data"]["status"] == "degraded"
        assert data["data"]["db_connected"] is False

        # verify session.close() 被调用
        mock_session.close.assert_called_once()
