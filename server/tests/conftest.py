"""
FarmEye Guard v1.0 — 测试配置与全局 Fixture

提供 pytest 钩子、Mock 数据库会话、FastAPI 依赖覆盖和异步测试客户端，
以及 IoTDA Webhook 测试所需的标准示例 Payload。
"""
import asyncio
from unittest.mock import MagicMock
from typing import AsyncGenerator

import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport

from app.main import app
from app.api.deps import get_db, verify_api_key


# ===========================================================================
# pytest 钩子：自定义命令行选项与标记
# ===========================================================================


def pytest_addoption(parser):
    """注册 --run-e2e / --run-docker / --run-integration / --run-performance 选项。"""
    parser.addoption(
        "--run-e2e",
        action="store_true",
        default=False,
        help="Run end-to-end tests",
    )
    parser.addoption(
        "--run-docker",
        action="store_true",
        default=False,
        help="Run Docker container tests",
    )
    parser.addoption(
        "--run-integration",
        action="store_true",
        default=False,
        help="Run integration tests (require real DB)",
    )
    parser.addoption(
        "--run-performance",
        action="store_true",
        default=False,
        help="Run performance tests",
    )


def pytest_configure(config):
    """注册 e2e / docker / integration / performance / slow 标记。"""
    config.addinivalue_line("markers", "e2e: End-to-end test (requires full environment)")
    config.addinivalue_line("markers", "docker: Docker container test")
    config.addinivalue_line("markers", "integration: Integration test (requires real DB)")
    config.addinivalue_line("markers", "performance: Performance/load test")
    config.addinivalue_line("markers", "slow: Slow test")


def pytest_collection_modifyitems(config, items):
    """根据命令行选项，条件性跳过标记的测试。"""
    skip_e2e = pytest.mark.skip(reason="need --run-e2e option to run")
    skip_docker = pytest.mark.skip(reason="need --run-docker option to run")
    skip_integration = pytest.mark.skip(reason="need --run-integration option to run")
    skip_performance = pytest.mark.skip(reason="need --run-performance option to run")

    for item in items:
        if "e2e" in item.keywords and not config.getoption("--run-e2e"):
            item.add_marker(skip_e2e)
        if "docker" in item.keywords and not config.getoption("--run-docker"):
            item.add_marker(skip_docker)
        if "integration" in item.keywords and not config.getoption("--run-integration"):
            item.add_marker(skip_integration)
        if "performance" in item.keywords and not config.getoption("--run-performance"):
            item.add_marker(skip_performance)


# ===========================================================================
# 事件循环（session 级，复用事件循环）
# ===========================================================================


@pytest.fixture(scope="session")
def event_loop():
    """Session 级事件循环，所有异步测试共享同一事件循环。"""
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


# ===========================================================================
# Mock 数据库会话
# ===========================================================================


@pytest.fixture
def mock_db_session():
    """Mock SQLAlchemy Session，支持链式查询 Mock。"""
    return MagicMock()


# ===========================================================================
# FastAPI 依赖覆盖（自动生效）
# ===========================================================================


@pytest.fixture(autouse=True)
def override_dependencies(mock_db_session):
    """
    全局覆盖 FastAPI 依赖注入：

    - verify_api_key -> lambda: None（跳过 API Key 认证）
    - get_db        -> lambda: mock_db_session（Mock 数据库会话）
    """
    app.dependency_overrides[verify_api_key] = lambda: None
    app.dependency_overrides[get_db] = lambda: mock_db_session
    yield
    app.dependency_overrides.pop(verify_api_key, None)
    app.dependency_overrides.pop(get_db, None)


# ===========================================================================
# 异步测试客户端
# ===========================================================================


@pytest_asyncio.fixture
async def async_client() -> AsyncGenerator[AsyncClient, None]:
    """
    异步 HTTP 测试客户端。

    使用 httpx.AsyncClient + ASGITransport 包装 FastAPI app，
    所有 API 调用无需真实网络端口。
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client


# ===========================================================================
# 示例 IoTDA Payload  Fixtures
# ===========================================================================


@pytest.fixture
def sample_sensor_payload() -> dict:
    """传感器属性上报标准 Payload（与设计文档 §4.1.3 一致）。"""
    return {
        "resource": "device.property",
        "event": "report",
        "event_time": "20250101T120000Z",
        "notify_data": {
            "header": {"device_id": "test_dev_001"},
            "body": {
                "services": [
                    {
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
                            "alarm_flag": 0,
                        },
                    }
                ],
            },
        },
    }


@pytest.fixture
def sample_ai_payload() -> dict:
    """AI 识别结果上报标准 Payload。"""
    return {
        "resource": "device.message",
        "event": "report",
        "event_time": "20250101T120000Z",
        "notify_data": {
            "header": {"device_id": "test_dev_001"},
            "body": {
                "services": [
                    {
                        "service_id": "farmeye_ai",
                        "properties": {
                            "crop_type": "wheat",
                            "disease_type": "powdery_mildew",
                            "object_number": 2,
                            "max_conf": 0.95,
                            "all_object": [
                                {"类别": "powdery_mildew", "置信度": 0.95, "位置": [10.0, 20.0, 50.0, 60.0]},
                                {"类别": "powdery_mildew", "置信度": 0.88, "位置": [30.0, 40.0, 70.0, 80.0]}
                            ],
                            "timestamp": 1782736281.0
                        },
                    }
                ],
            },
        },
    }


@pytest.fixture
def sample_command_response_payload() -> dict:
    """命令应答上报标准 Payload。"""
    return {
        "notify_data": {
            "header": {"device_id": "test_dev_001"},
            "body": {
                "services": [
                    {
                        "service_id": "farmeye_env",
                        "properties": {
                            "command_id": "cmd_001",
                            "result_code": 0,
                            "result_msg": "success",
                        },
                    }
                ],
            },
        },
    }
