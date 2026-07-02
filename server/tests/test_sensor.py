"""
FarmEye Guard v1.0 — 传感器查询 API 单元测试

覆盖用例 #10-#16：
  #10 test_latest_with_device_id   指定 device_id → 单条
  #11 test_latest_all              不指定 device_id → 全部
  #12 test_history_pagination      分页查询
  #13 test_history_time_range      时间范围筛选
  #14 test_page_size_cap           page_size 截断至 100
  #15 test_page_out_of_range       page 超范围 → 空列表
  #16 test_daily_aggregation       日聚合查询

测试策略：Mock sensor_service 层的函数，确保 API 路由逻辑正确。
"""
from datetime import datetime, date
from unittest.mock import patch

import pytest


def _make_snapshot(
    device_id: str = "dev_001",
    temperature: float = 25.5,
    humidity: float = 60.0,
    timestamp=None,
):
    """构建模拟传感器快照对象（属性兼容 SensorSnapshotRead）。"""
    ts = timestamp or datetime(2025, 1, 1, 12, 0, 0)
    return type(
        "MockSnapshot",
        (),
        {
            "id": 1,
            "device_id": device_id,
            "mac_addr": "AA:BB:CC:DD:EE:FF",
            "timestamp": ts,
            "temperature": temperature,
            "humidity": humidity,
            "light": 45000,
            "co2": 420,
            "soil_n": 12.5,
            "soil_p": 8.3,
            "soil_k": 15.7,
            "distance": 35,
            "rssi": -65,
            "ip_addr": "192.168.1.100",
            "alarm_flag": 0,
            "created_at": ts,
        },
    )()


def _make_aggregation(device_id: str = "dev_001", agg_date_str: str = "2025-01-01"):
    """构建模拟日聚合对象。"""
    return type(
        "MockAggregation",
        (),
        {
            "id": 1,
            "device_id": device_id,
            "agg_date": date.fromisoformat(agg_date_str),
            "avg_temperature": 24.0,
            "max_temperature": 28.0,
            "min_temperature": 20.0,
            "avg_humidity": 55.0,
            "max_humidity": 65.0,
            "min_humidity": 45.0,
            "avg_light": 40000.0,
            "max_light": 50000,
            "min_light": 30000,
            "avg_co2": 400.0,
            "max_co2": 450,
            "min_co2": 350,
            "record_count": 144,
            "created_at": datetime(2025, 1, 1, 23, 59, 59),
        },
    )()


# =========================================================================
# 最新数据查询
# =========================================================================


@pytest.mark.asyncio
async def test_latest_with_device_id(async_client):
    """
    用例 #10：指定 device_id 查询最新传感器数据。

    预期：返回单条记录，device_id 匹配。
    """
    mock_snapshot = _make_snapshot(device_id="dev_001")

    with patch("app.api.v1.sensor.get_latest_snapshots") as mock_get:
        mock_get.return_value = [mock_snapshot]

        response = await async_client.get(
            "/api/v1/sensor/latest?device_id=dev_001"
        )

        assert response.status_code == 200
        data = response.json()
        assert data["code"] == 0
        assert data["data"]["device_id"] == "dev_001"
        assert data["data"]["temperature"] == 25.5
        mock_get.assert_called_once()


@pytest.mark.asyncio
async def test_latest_all(async_client):
    """
    用例 #11：不指定 device_id，返回所有设备最新记录。

    预期：返回列表，包含多条记录。
    """
    snapshots = [
        _make_snapshot(device_id="dev_001"),
        _make_snapshot(device_id="dev_002", temperature=30.0),
    ]

    with patch("app.api.v1.sensor.get_latest_snapshots") as mock_get:
        mock_get.return_value = snapshots

        response = await async_client.get("/api/v1/sensor/latest")

        assert response.status_code == 200
        data = response.json()
        assert data["code"] == 0
        assert isinstance(data["data"], list)
        assert len(data["data"]) == 2
        assert data["data"][0]["device_id"] == "dev_001"
        assert data["data"][1]["device_id"] == "dev_002"


# =========================================================================
# 历史数据查询
# =========================================================================


@pytest.mark.asyncio
async def test_history_pagination(async_client):
    """
    用例 #12：分页查询历史数据。

    预期：page=1, page_size=10 → records 10 条 + pagination.total。
    """
    records = [_make_snapshot() for _ in range(10)]

    with patch("app.api.v1.sensor.get_sensor_history") as mock_get:
        mock_get.return_value = (records, 50)  # (records, total)

        response = await async_client.get(
            "/api/v1/sensor/history?device_id=dev_001&page=1&page_size=10"
        )

        assert response.status_code == 200
        data = response.json()
        assert data["code"] == 0
        assert len(data["data"]["records"]) == 10
        assert data["data"]["pagination"]["total"] == 50
        assert data["data"]["pagination"]["page"] == 1
        assert data["data"]["pagination"]["page_size"] == 10


@pytest.mark.asyncio
async def test_history_time_range(async_client):
    """
    用例 #13：时间范围筛选。

    预期：仅返回时间范围内的记录。
    """
    records = [_make_snapshot()]

    with patch("app.api.v1.sensor.get_sensor_history") as mock_get:
        mock_get.return_value = (records, 1)

        response = await async_client.get(
            "/api/v1/sensor/history?device_id=dev_001"
            "&start=2025-01-01T00:00:00Z&end=2025-01-02T00:00:00Z"
        )

        assert response.status_code == 200
        data = response.json()
        assert data["code"] == 0
        assert len(data["data"]["records"]) == 1


@pytest.mark.asyncio
async def test_page_size_cap(async_client):
    """
    用例 #14：page_size 超限截断。

    page_size=200 超过 le=100 的 Query 校验上限，
    预期返回 422（FastAPI 查询参数校验拒绝）。
    """
    response = await async_client.get(
        "/api/v1/sensor/history?device_id=dev_001&page_size=200"
    )

    # Query 参数 le=100 拒绝 page_size=200
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_page_out_of_range(async_client):
    """
    用例 #15：page 超出范围。

    page=9999 → 返回空 records 列表。
    """
    with patch("app.api.v1.sensor.get_sensor_history") as mock_get:
        mock_get.return_value = ([], 0)

        response = await async_client.get(
            "/api/v1/sensor/history?device_id=dev_001&page=9999"
        )

        assert response.status_code == 200
        data = response.json()
        assert data["code"] == 0
        assert data["data"]["records"] == []
        assert data["data"]["pagination"]["total"] == 0


# =========================================================================
# 日聚合数据
# =========================================================================


@pytest.mark.asyncio
async def test_daily_aggregation(async_client):
    """
    用例 #16：查询日聚合数据。

    预期：返回 2025-01-01 ~ 2025-01-07 范围内的聚合记录。
    """
    aggs = [_make_aggregation(agg_date_str="2025-01-01")]

    with patch("app.api.v1.sensor.get_daily_aggregation") as mock_get:
        mock_get.return_value = (aggs, 1)

        response = await async_client.get(
            "/api/v1/sensor/daily?device_id=dev_001"
            "&start=2025-01-01&end=2025-01-07"
        )

        assert response.status_code == 200
        data = response.json()
        assert data["code"] == 0
        assert len(data["data"]["records"]) == 1
        assert data["data"]["records"][0]["agg_date"] == "2025-01-01"
        assert data["data"]["records"][0]["record_count"] == 144
        assert data["data"]["pagination"]["total"] == 1
