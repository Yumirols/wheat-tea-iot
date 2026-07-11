"""
FarmEye Guard v1.0 — 基础架构与核心组件单元测试

覆盖：
  - app/api/deps.py (verify_api_key)
  - app/core/logging_config.py (setup_logging)
  - app/db/session.py (get_db)
  - app/main.py (startup/shutdown events, root, health_check)
"""
import pytest
from unittest.mock import patch, MagicMock
from fastapi import HTTPException
from sqlalchemy import text

from app.config import settings
from app.api.deps import verify_api_key
from app.core.logging_config import setup_logging
from app.db.session import get_db
from app.main import on_startup, on_shutdown, root, health_check


# =========================================================================
# 1. app/api/deps.py
# =========================================================================

@pytest.mark.asyncio
async def test_verify_api_key_empty_settings():
    """测试 settings.API_KEYS 为空时跳过验证"""
    with patch("app.api.deps.settings") as mock_settings:
        mock_settings.API_KEYS = ""
        res = await verify_api_key("some_key")
        assert res is None


@pytest.mark.asyncio
async def test_verify_api_key_valid():
    """测试合法的 API Key"""
    with patch("app.api.deps.settings") as mock_settings:
        mock_settings.API_KEYS = "key1, key2 , key3"
        res = await verify_api_key("key2")
        assert res == "key2"


@pytest.mark.asyncio
async def test_verify_api_key_invalid():
    """测试不合法的 API Key 或缺失 Key"""
    with patch("app.api.deps.settings") as mock_settings:
        mock_settings.API_KEYS = "key1, key2"
        # 1. 缺失 Key
        with pytest.raises(HTTPException) as exc_info:
            await verify_api_key(None)
        assert exc_info.value.status_code == 401
        
        # 2. 错误的 Key
        with pytest.raises(HTTPException) as exc_info:
            await verify_api_key("invalid_key")
        assert exc_info.value.status_code == 401


# =========================================================================
# 2. app/core/logging_config.py
# =========================================================================

def test_setup_logging():
    """测试日志初始化设置"""
    with patch("app.core.logging_config.Path.mkdir") as mock_mkdir, \
         patch("app.core.logging_config.RotatingFileHandler") as mock_rotating_handler, \
         patch("app.core.logging_config.logging.StreamHandler") as mock_stream_handler, \
         patch("app.core.logging_config.logging.getLogger") as mock_get_logger:
        
        mock_root_logger = MagicMock()
        mock_get_logger.return_value = mock_root_logger
        
        setup_logging()
        
        mock_mkdir.assert_called_once_with(parents=True, exist_ok=True)
        # 校验控制台和文件两个 handler 均注册到了 root logger
        assert mock_root_logger.addHandler.call_count == 2


# =========================================================================
# 3. app/db/session.py
# =========================================================================

def test_get_db():
    """测试 get_db 依赖注入生成器"""
    mock_session = MagicMock()
    with patch("app.db.session.SessionLocal", return_value=mock_session):
        db_gen = get_db()
        db = next(db_gen)
        assert db == mock_session
        
        # 模拟生成器生命周期结束
        try:
            next(db_gen)
        except StopIteration:
            pass
            
        mock_session.close.assert_called_once()


# =========================================================================
# 4. app/main.py
# =========================================================================

@pytest.mark.asyncio
async def test_app_startup_shutdown():
    """测试应用的启动与关闭生命周期事件"""
    with patch("app.main.setup_logging") as mock_setup:
        await on_startup()
        mock_setup.assert_called_once()
        
    # 执行 shutdown 不应抛出异常
    await on_shutdown()


@pytest.mark.asyncio
async def test_app_root():
    """测试默认根路由"""
    res = await root()
    assert res == {"message": "FarmEye Guard API"}


@pytest.mark.asyncio
async def test_app_health_check_healthy():
    """测试健康检查 — 数据库连接正常"""
    mock_db = MagicMock()
    with patch("app.main.SessionLocal", return_value=mock_db):
        response = await health_check()
        assert response.status_code == 200
        
        # 检查是否执行了相关的 SQL 语句
        calls = [c[0][0] for c in mock_db.execute.call_args_list]
        sqls = [getattr(stmt, "text", str(stmt)) for stmt in calls]
        assert any("SELECT 1" in sql for sql in sqls)
        assert any("statement_timeout" in sql for sql in sqls)
        
        mock_db.commit.assert_called_once()
        mock_db.close.assert_called_once()


@pytest.mark.asyncio
async def test_app_health_check_degraded():
    """测试健康检查 — 数据库连接失败"""
    mock_db = MagicMock()
    mock_db.execute.side_effect = Exception("Connection refused")
    with patch("app.main.SessionLocal", return_value=mock_db):
        response = await health_check()
        assert response.status_code == 503
        
        mock_db.close.assert_called_once()
