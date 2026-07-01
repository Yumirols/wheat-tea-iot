"""
FarmEye Guard v1.0 — FastAPI 应用入口

创建 FastAPI 应用实例，注册生命周期事件、中间件和路由。
提供默认根路径响应和健康检查端点。
"""
import time
import logging
from sqlalchemy import text
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.config import settings
from app.core.logging_config import setup_logging
from app.db.session import SessionLocal
from app.api.router import api_router

logger = logging.getLogger(__name__)

# 模块级变量：应用启动时间戳
START_TIME = time.time()


app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
)


# ── 中间件 ──────────────────────────────────────────────────────

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── 路由注册 ────────────────────────────────────────────────────

app.include_router(api_router)


# ── 生命周期事件 ────────────────────────────────────────────────

@app.on_event("startup")
async def on_startup() -> None:
    """应用启动时执行：配置日志、输出启动信息"""
    setup_logging()
    logger.info(
        "%s v%s starting up...",
        settings.PROJECT_NAME,
        settings.VERSION,
    )


@app.on_event("shutdown")
async def on_shutdown() -> None:
    """应用关闭时执行：清理资源"""
    logger.info("%s shutting down...", settings.PROJECT_NAME)


# ── 默认根路径 ──────────────────────────────────────────────────

@app.get("/")
async def root() -> dict:
    """根路径返回基本信息"""
    return {"message": "FarmEye Guard API"}


# ── 健康检查端点 ────────────────────────────────────────────────

@app.get(f"{settings.API_V1_PREFIX}/health")
async def health_check() -> JSONResponse:
    """
    健康检查端点。

    检查数据库连接状态，返回服务健康状况。
    - 数据库连接正常：HTTP 200, status="healthy"
    - 数据库连接失败：HTTP 503, status="degraded"
    """
    db_connected = False
    status = "healthy"

    db = SessionLocal()
    try:
        # 设置 2 秒语句超时，确保数据库无响应时快速降级
        db.execute(text("SET statement_timeout TO '2000'"))
        db.execute(text("SELECT 1"))
        db.commit()
        db_connected = True
    except Exception as exc:
        logger.warning("Health check — database connection failed: %s", exc)
        status = "degraded"
    finally:
        db.close()

    uptime_seconds = time.time() - START_TIME

    response_data = {
        "code": 0,
        "message": "success",
        "data": {
            "status": status,
            "uptime_seconds": uptime_seconds,
            "db_connected": db_connected,
            "version": settings.VERSION,
        },
    }

    status_code = 200 if db_connected else 503
    return JSONResponse(content=response_data, status_code=status_code)
