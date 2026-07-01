"""
FarmEye Guard v1.0 — 数据库会话管理

提供 SQLAlchemy 引擎、会话工厂和 FastAPI 依赖注入生成器。
"""
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.config import settings

engine = create_engine(
    settings.DATABASE_URL,
    pool_size=2,
    max_overflow=2,
    pool_pre_ping=True,
)

SessionLocal = sessionmaker(
    bind=engine,
    autoflush=False,
    autocommit=False,
)


def get_db():
    """
    FastAPI 依赖注入生成器。

    在请求处理期间提供一个 SQLAlchemy 会话实例。
    请求完成后自动关闭会话，归还连接至连接池。
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
