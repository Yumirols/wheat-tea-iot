"""
FarmEye Guard v1.0 — 日志配置模块

配置应用日志，支持控制台输出和文件轮转两种方式。
日志级别从应用配置动态读取。
"""
import logging
import sys
from logging.handlers import RotatingFileHandler
from pathlib import Path

from app.config import settings

LOG_DIR = Path("./logs")


def setup_logging() -> None:
    """配置应用日志系统"""
    LOG_DIR.mkdir(parents=True, exist_ok=True)

    formatter = logging.Formatter(
        fmt="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    # 控制台输出
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setFormatter(formatter)

    # 文件输出（10MB 轮转，保留 5 个文件）
    file_handler = RotatingFileHandler(
        LOG_DIR / "app.log",
        maxBytes=10 * 1024 * 1024,
        backupCount=5,
        encoding="utf-8",
    )
    file_handler.setFormatter(formatter)

    root_logger = logging.getLogger()
    root_logger.setLevel(getattr(logging, settings.LOG_LEVEL.upper(), logging.INFO))
    root_logger.addHandler(console_handler)
    root_logger.addHandler(file_handler)

    # 第三方库日志级别调整
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)
    logging.getLogger("httpx").setLevel(logging.WARNING)
