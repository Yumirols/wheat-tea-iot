"""
FarmEye Guard v1.0 — 集成测试专用 Fixture 与配置

本 conftest 文件提供集成测试所需的核心基础设施：

  1. test_engine (session-scoped)
     - 创建 farmeye_test 数据库（如不存在）
     - Base.metadata.create_all() 物理建表
     - 额外创建 SQL 级别的 UNIQUE 索引

  2. db_session (function-scoped)
     - 每个测试使用独立连接和事务
     - 测试结束后 ROLLBACK 事务，完全隔离

  3. override_deps (autouse)
     - 覆盖 FastAPI get_db 为真实事务 Session
     - 覆盖 verify_api_key 跳过认证

注意：
  本 conftest 与全局 tests/conftest.py 协作。全局 conftest 已注册
  --run-integration 选项和 integration 标记。运行集成测试需要：
      pytest tests/integration/ --run-integration
"""
import logging
from typing import AsyncGenerator

import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from sqlalchemy import create_engine, text, Engine
from sqlalchemy.orm import Session

from app.main import app
from app.api.deps import get_db, verify_api_key
from app.config import settings
from app.db.base import Base

logger = logging.getLogger(__name__)

# ===========================================================================
# 测试数据库 URL 推导
# ===========================================================================

# 从 settings.DATABASE_URL 推导测试数据库 URL
# 生产/开发: postgresql+psycopg2://farmeye:farmeye_pwd@localhost:5432/farmeye_db
# 测试:      postgresql+psycopg2://farmeye:farmeye_pwd@localhost:5432/farmeye_test
_DEFAULT_DB_NAME = "farmeye_db"
_TEST_DB_NAME = "farmeye_test"
_TEST_DATABASE_URL = settings.DATABASE_URL.replace(
    _DEFAULT_DB_NAME, _TEST_DB_NAME, 1
)

# 用于 CREATE DATABASE 的管理员连接（连接默认 postgres 库）
_ADMIN_DATABASE_URL = settings.DATABASE_URL.replace(
    f"/{_DEFAULT_DB_NAME}", "/postgres", 1
)


# ===========================================================================
# Session 级: 测试引擎 & 数据库初始化
# ===========================================================================


def _ensure_test_database() -> None:
    """确保 farmeye_test 数据库存在，不存在则创建。"""
    admin_engine = create_engine(_ADMIN_DATABASE_URL, isolation_level="AUTOCOMMIT")
    try:
        with admin_engine.connect() as conn:
            # 检查数据库是否已存在
            result = conn.execute(
                text(
                    "SELECT 1 FROM pg_database WHERE datname = :dbname"
                ),
                {"dbname": _TEST_DB_NAME},
            )
            if result.scalar() is None:
                conn.execute(text(f'CREATE DATABASE "{_TEST_DB_NAME}"'))
                logger.info("Created test database: %s", _TEST_DB_NAME)
            else:
                logger.info("Test database already exists: %s", _TEST_DB_NAME)
    finally:
        admin_engine.dispose()


def _create_additional_indexes(engine: Engine) -> None:
    """
    创建 ORM 模型中未定义但生产 DDL 中存在的 UNIQUE 索引。

    生产环境通过 init/01_create_tables.sql 创建以下索引：
      - idx_sensor_device_time: UNIQUE ON sensor_snapshot(device_id, timestamp)
      - idx_disease_device_time: UNIQUE ON disease_records(device_id, timestamp, disease_type)
      - idx_control_command_id: UNIQUE ON control_logs(command_id) WHERE command_id IS NOT NULL
      - idx_control_device_time: ON control_logs(device_id, timestamp)
      - idx_agg_device_date: ON sensor_daily_aggregation(device_id, agg_date)
      - idx_devices_device_id: ON devices(device_id)
    """
    statements = [
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_sensor_device_time "
        "ON sensor_snapshot (device_id, timestamp)",
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_disease_device_time "
        "ON disease_records (device_id, timestamp, disease_type)",
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_control_command_id "
        "ON control_logs (command_id) WHERE command_id IS NOT NULL",
        "CREATE INDEX IF NOT EXISTS idx_control_device_time "
        "ON control_logs (device_id, timestamp)",
        "CREATE INDEX IF NOT EXISTS idx_agg_device_date "
        "ON sensor_daily_aggregation (device_id, agg_date)",
        "CREATE INDEX IF NOT EXISTS idx_devices_device_id "
        "ON devices (device_id)",
    ]
    with engine.connect() as conn:
        for stmt in statements:
            conn.execute(text(stmt))
        conn.commit()


@pytest.fixture(scope="session")
def test_engine() -> Engine:
    """
    Session 级 fixture：创建测试数据库引擎。

    职责：
      1. 确保 farmeye_test 数据库存在
      2. 通过 Base.metadata.create_all() 建表
      3. 创建 SQL 级别的索引
      4. 返回绑定到 farmeye_test 的 Engine
    """
    _ensure_test_database()

    engine = create_engine(
        _TEST_DATABASE_URL,
        pool_size=2,
        max_overflow=2,
        pool_pre_ping=True,
    )

    # 清理并重建表，确保 schema 与模型定义一致
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    logger.info("Recreated all ORM tables via Base.metadata.drop_all/create_all()")

    # SQL 级索引
    _create_additional_indexes(engine)
    logger.info("Created additional SQL-level indexes")

    yield engine

    engine.dispose()
    logger.info("Test engine disposed")


# ===========================================================================
# 函数级: 事务回滚隔离
# ===========================================================================


@pytest.fixture
def db_session(test_engine: Engine) -> Session:
    """
    函数级 fixture：提供独立事务的数据库会话。

    实现 savepoint 级回滚隔离：
      - 每个测试获得独立数据库连接
      - 使用 join_transaction_mode="create_savepoint" 模式，
        session.commit() 仅释放 savepoint（非提交外层事务），
        session.rollback() 仅回滚到 savepoint。
      - 测试结束后 ROLLBACK 外层事务，撤销所有变更。
      - 完全隔离，测试间互不影响。

    使用示例：
        def test_insert(db_session: Session):
            record = SensorSnapshot(device_id="dev_001", ...)
            db_session.add(record)
            db_session.commit()
            assert record.id is not None
            # 测试结束后自动 ROLLBACK，不污染数据库
    """
    connection = test_engine.connect()
    transaction = connection.begin()
    session = Session(
        bind=connection,
        join_transaction_mode="create_savepoint",
    )

    yield session

    session.close()
    transaction.rollback()
    connection.close()


# ===========================================================================
# autouse: 依赖注入覆盖
# ===========================================================================


@pytest.fixture(autouse=True)
def override_deps(db_session: Session) -> None:
    """
    自动生效的 fixture：覆盖 FastAPI 依赖注入。

    覆盖项：
      - get_db -> 返回真实事务 Session (db_session)
      - verify_api_key -> 跳过 API Key 认证

    由于全局 conftest.py 也有 autouse 的 override_dependencies，
    本 fixture 在其之后执行，覆盖 get_db 为真实 Session。
    """
    app.dependency_overrides[get_db] = lambda: db_session
    app.dependency_overrides[verify_api_key] = lambda: None
    yield
    app.dependency_overrides.pop(get_db, None)
    app.dependency_overrides.pop(verify_api_key, None)


# ===========================================================================
# 异步测试客户端（覆盖全局，确保集成测试上下文一致）
# ===========================================================================


@pytest_asyncio.fixture
async def async_client() -> AsyncGenerator[AsyncClient, None]:
    """
    异步 HTTP 测试客户端。

    使用 ASGITransport 包装 FastAPI app，集成测试的依赖覆盖
    (override_deps) 已通过 app.dependency_overrides 生效。
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client


# ===========================================================================
# 共享测试数据
# ===========================================================================


@pytest.fixture
def test_device_id() -> str:
    """集成测试使用的设备 ID。"""
    return "integration_test_dev_001"


@pytest.fixture
def sample_sensor_properties() -> dict:
    """传感器属性字段值。"""
    return {
        "temperature": 26.3,
        "humidity": 72.5,
        "light": 32000,
        "co2": 410,
        "soil_n": 15.2,
        "soil_p": 9.1,
        "soil_k": 18.4,
        "distance": 42,
        "rssi": -58,
        "ip_addr": "10.0.0.1",
        "mac_addr": "11:22:33:44:55:66",
        "alarm_flag": 0,
    }


@pytest.fixture
def sample_sensor_payload(test_device_id: str, sample_sensor_properties: dict) -> dict:
    """完整传感器属性上报 payload。"""
    from datetime import datetime
    return {
        "resource": "device.property",
        "event": "report",
        "event_time": datetime.utcnow().strftime("%Y%m%dT%H%M%SZ"),
        "notify_data": {
            "header": {"device_id": test_device_id},
            "body": {
                "services": [
                    {
                        "service_id": "farmeye_env",
                        "properties": sample_sensor_properties,
                    }
                ],
            },
        },
    }


@pytest.fixture
def sample_ai_payload_high(test_device_id: str) -> dict:
    """重度病害 AI 识别结果上报 payload (object_number=4 -> severity_code=3)。"""
    from datetime import datetime
    return {
        "resource": "device.message",
        "event": "report",
        "event_time": datetime.utcnow().strftime("%Y%m%dT%H%M%SZ"),
        "notify_data": {
            "header": {"device_id": test_device_id},
            "body": {
                "services": [
                    {
                        "service_id": "farmeye_ai",
                        "properties": {
                            "crop_type": "wheat",
                            "disease_type": "rust",
                            "object_number": 4,
                            "max_conf": 0.95,
                            "all_object": [
                                {"类别": "rust", "置信度": 0.95, "位置": [10.0, 20.0, 50.0, 60.0]},
                                {"类别": "rust", "置信度": 0.92, "位置": [12.0, 22.0, 52.0, 62.0]},
                                {"类别": "rust", "置信度": 0.88, "位置": [14.0, 24.0, 54.0, 64.0]},
                                {"类别": "rust", "置信度": 0.85, "位置": [16.0, 26.0, 56.0, 66.0]}
                            ],
                            "timestamp": 1782736281.0
                        },
                    }
                ],
            },
        },
    }


@pytest.fixture
def sample_ai_payload_moderate(test_device_id: str) -> dict:
    """中度病害 AI 识别结果上报 payload (object_number=2 -> severity_code=2)。"""
    from datetime import datetime
    return {
        "resource": "device.message",
        "event": "report",
        "event_time": datetime.utcnow().strftime("%Y%m%dT%H%M%SZ"),
        "notify_data": {
            "header": {"device_id": test_device_id},
            "body": {
                "services": [
                    {
                        "service_id": "farmeye_ai",
                        "properties": {
                            "crop_type": "wheat",
                            "disease_type": "powdery_mildew",
                            "object_number": 2,
                            "max_conf": 0.88,
                            "all_object": [
                                {"类别": "powdery_mildew", "置信度": 0.88, "位置": [10.0, 20.0, 50.0, 60.0]},
                                {"类别": "powdery_mildew", "置信度": 0.82, "位置": [30.0, 40.0, 70.0, 80.0]}
                            ],
                            "timestamp": 1782736281.0
                        },
                    }
                ],
            },
        },
    }
