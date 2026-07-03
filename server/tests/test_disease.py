"""
FarmEye Guard v1.0 — 病虫害查询 API 单元测试

覆盖用例 #18-#22：
  #18 test_list_with_filters   多条件筛选
  #19 test_list_time_range     时间范围筛选
  #20 test_statistics          统计接口
  #21 test_heatmap             热力图接口
  #22 test_empty_result        无匹配 → 空列表

测试策略：Mock disease_service 层函数。
"""
from datetime import datetime
from unittest.mock import patch

import pytest


def _make_disease_record(
    disease_id: int = 1,
    device_id: str = "dev_001",
    crop_type: str = "wheat",
    disease_type: str = "powdery_mildew",
    severity: str = "Moderate",
):
    """构建模拟病虫害记录对象。"""
    return type(
        "MockDiseaseRecord",
        (),
        {
            "id": disease_id,
            "device_id": device_id,
            "timestamp": datetime(2025, 1, 1, 12, 0, 0),
            "crop_type": crop_type,
            "disease_type": disease_type,
            "max_conf": 0.95,
            "severity": severity,
            "severity_code": 2,
            "object_number": 2,
            "all_object": [{"类别": disease_type, "置信度": 0.95, "位置": [10.0, 20.0, 50.0, 60.0]}],
            "linkage_risk_level": None,
            "linkage_detail": None,
            "image_path": None,
            "action_taken": None,
            "created_at": datetime(2025, 1, 1, 12, 0, 0),
        },
    )()


# =========================================================================
# 记录列表
# =========================================================================


@pytest.mark.asyncio
async def test_list_with_filters(async_client):
    """
    用例 #18：多条件筛选查询。

    查询参数 crop_type=wheat, severity=Moderate，
    预期返回筛选后的记录列表。
    """
    records = [
        _make_disease_record(
            disease_id=1,
            crop_type="wheat",
            disease_type="powdery_mildew",
            severity="Moderate",
        )
    ]

    with patch("app.api.v1.disease.get_disease_records") as mock_get:
        mock_get.return_value = (records, 1)

        response = await async_client.get(
            "/api/v1/disease/list?crop_type=wheat&severity=Moderate"
        )

        assert response.status_code == 200
        data = response.json()
        assert data["code"] == 0
        assert len(data["data"]["records"]) == 1
        assert data["data"]["records"][0]["crop_type"] == "wheat"
        assert data["data"]["records"][0]["severity"] == "Moderate"


@pytest.mark.asyncio
async def test_list_time_range(async_client):
    """
    用例 #19：时间范围筛选。

    查询参数 start + end，预期返回范围内记录。
    """
    records = [_make_disease_record()]

    with patch("app.api.v1.disease.get_disease_records") as mock_get:
        mock_get.return_value = (records, 1)

        response = await async_client.get(
            "/api/v1/disease/list"
            "?start=2025-01-01T00:00:00Z&end=2025-01-31T00:00:00Z"
        )

        assert response.status_code == 200
        data = response.json()
        assert data["code"] == 0
        assert len(data["data"]["records"]) == 1


# =========================================================================
# 统计接口
# =========================================================================


@pytest.mark.asyncio
async def test_statistics(async_client):
    """
    用例 #20：病虫害统计接口。

    预期返回 by_crop / by_severity / by_disease 等统计数据。
    """
    mock_stats = {
        "total_detections": 10,
        "by_crop": {"wheat": 8, "tea": 2},
        "by_severity": {"Mild": 3, "Moderate": 5, "Severe": 2},
        "by_disease": {"powdery_mildew": 4, "rust": 4, "anthracnose": 2},
    }

    with patch("app.api.v1.disease.get_disease_stats") as mock_get:
        mock_get.return_value = mock_stats

        response = await async_client.get("/api/v1/disease/stats")

        assert response.status_code == 200
        data = response.json()
        assert data["code"] == 0
        assert data["data"]["total_detections"] == 10
        assert data["data"]["by_crop"]["wheat"] == 8
        assert data["data"]["by_severity"]["Moderate"] == 5


# =========================================================================
# 热力图
# =========================================================================


@pytest.mark.asyncio
async def test_heatmap(async_client):
    """
    用例 #21：热力图数据接口。

    预期返回 heatmap_points + summary 结构。
    """
    mock_heatmap = {
        "heatmap_points": [
            {
                "device_id": "dev_001",
                "disease_type": "powdery_mildew",
                "severity": "Moderate",
                "timestamp": "2025-01-01T12:00:00",
                "crop_type": "wheat",
            }
        ],
        "summary": {
            "active_disease_types": 1,
            "affected_devices": 1,
            "total_records": 1,
        },
    }

    with patch("app.api.v1.disease.get_heatmap_data") as mock_get:
        mock_get.return_value = mock_heatmap

        response = await async_client.get("/api/v1/disease/heatmap")

        assert response.status_code == 200
        data = response.json()
        assert data["code"] == 0
        assert len(data["data"]["heatmap_points"]) == 1
        assert data["data"]["summary"]["active_disease_types"] == 1
        assert data["data"]["summary"]["affected_devices"] == 1


# =========================================================================
# 空结果
# =========================================================================


@pytest.mark.asyncio
async def test_empty_result(async_client):
    """
    用例 #22：无匹配条件 → 空结果。

    预期返回空 records 列表和 total=0。
    """
    with patch("app.api.v1.disease.get_disease_records") as mock_get:
        mock_get.return_value = ([], 0)

        response = await async_client.get(
            "/api/v1/disease/list?crop_type=non_existent"
        )

        assert response.status_code == 200
        data = response.json()
        assert data["code"] == 0
        assert data["data"]["records"] == []
        assert data["data"]["pagination"]["total"] == 0
