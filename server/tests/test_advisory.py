"""
FarmEye Guard v1.0 — 防治建议 API 单元测试

覆盖用例 #29-#31：
  #29 test_advisory_with_detection      有检测记录 → latest_detection + advisory
  #30 test_advisory_no_detection         无检测记录 → advisory 为 null
  #31 test_advisory_with_env_linkage     有检测 + 环境数据 → env_disease_linkage

测试策略：Mock advisory_service.get_advisory 函数。
"""
from unittest.mock import patch

import pytest


@pytest.mark.asyncio
async def test_advisory_with_detection(async_client):
    """
    用例 #29：时间窗口内有最新 AI 识别记录。

    预期：
      - code = 0
      - data.latest_detection 存在
      - data.advisory 存在
    """
    mock_result = {
        "latest_detection": {
            "crop_type": "wheat",
            "disease_type": "powdery_mildew",
            "severity": "Moderate",
            "severity_code": 2,
            "max_conf": 0.95,
            "object_number": 2,
            "all_object": [{"类别": "powdery_mildew", "置信度": 0.95, "位置": [10.0, 20.0, 50.0, 60.0]}],
            "timestamp": "2025-01-01T12:00:00",
        },
        "current_env": None,
        "env_disease_linkage": None,
        "advisory": {
            "action": "manual_inspect",
            "description": "检测到中度小麦白粉病（severity_code=2），建议持续监测。当前环境条件暂未达到白粉病快速扩散条件。",
            "auto_action_triggered": False,
            "auto_action": None,
        },
    }

    with patch("app.api.v1.advisory.get_advisory") as mock_get:
        mock_get.return_value = mock_result

        response = await async_client.get("/api/v1/advisory?device_id=dev_001")

        assert response.status_code == 200
        data = response.json()
        assert data["code"] == 0
        assert data["data"]["latest_detection"] is not None
        assert data["data"]["latest_detection"]["crop_type"] == "wheat"
        assert data["data"]["advisory"] is not None
        assert data["data"]["advisory"]["action"] is not None


@pytest.mark.asyncio
async def test_advisory_no_detection(async_client):
    """
    用例 #30：时间窗口内无识别记录。

    预期：
      - code = 0
      - data.latest_detection 为 null
      - data.advisory 为 null
    """
    mock_result = {
        "latest_detection": None,
        "current_env": None,
        "env_disease_linkage": None,
        "advisory": None,
    }

    with patch("app.api.v1.advisory.get_advisory") as mock_get:
        mock_get.return_value = mock_result

        response = await async_client.get("/api/v1/advisory?device_id=dev_unknown")

        assert response.status_code == 200
        data = response.json()
        assert data["code"] == 0
        assert data["data"]["latest_detection"] is None
        assert data["data"]["advisory"] is None


@pytest.mark.asyncio
async def test_advisory_with_env_linkage(async_client):
    """
    用例 #31：有检测记录且有环境数据。

    预期：
      - code = 0
      - data.env_disease_linkage 存在，含 risk_level / matched_conditions / recommendation
    """
    mock_result = {
        "latest_detection": {
            "crop_type": "wheat",
            "disease_type": "rust",
            "severity": "Moderate",
            "severity_code": 2,
            "max_conf": 0.88,
            "object_number": 2,
            "all_object": [{"类别": "rust", "置信度": 0.88, "位置": [10.0, 20.0, 50.0, 60.0]}],
            "timestamp": "2025-01-01T12:00:00",
        },
        "current_env": {
            "temperature": 22.0,
            "humidity": 88.0,
            "light": 45000,
            "co2": 420,
        },
        "env_disease_linkage": {
            "risk_level": "high",
            "matched_conditions": [
                "湿度 88.0% 超过锈病扩散阈值 85%",
                "温度 22.0℃ 处于锈病适宜范围 15-25℃",
            ],
            "recommendation": "当前环境条件非常有利于锈病扩散",
        },
        "advisory": {
            "action": "spray_fungicide",
            "description": "检测到中度小麦锈病（severity_code=2），建议在48h内喷施三唑酮类杀菌剂。当前温湿度条件适宜锈病扩散，请加强监测频率。",
            "auto_action_triggered": False,
            "auto_action": None,
        },
    }

    with patch("app.api.v1.advisory.get_advisory") as mock_get:
        mock_get.return_value = mock_result

        response = await async_client.get("/api/v1/advisory?device_id=dev_001")

        assert response.status_code == 200
        data = response.json()
        assert data["code"] == 0
        assert data["data"]["latest_detection"] is not None
        assert data["data"]["current_env"] is not None
        assert data["data"]["env_disease_linkage"] is not None
        assert data["data"]["env_disease_linkage"]["risk_level"] == "high"
        assert len(data["data"]["env_disease_linkage"]["matched_conditions"]) == 2
        assert data["data"]["advisory"] is not None
