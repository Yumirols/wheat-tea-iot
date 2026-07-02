"""
FarmEye Guard v1.0 — Alembic 环境配置

数据库连接地址从 DATABASE_URL 环境变量动态读取，
支持跨环境部署场景：
- 本地开发：localhost:5432（server/.env.dev.example）
- Docker 容器内：db:5432（server/.env.prod.example）
- 测试环境：可通过 TEST_DATABASE_URL 或独立环境变量

离线模式（run_migrations_offline）：生成 SQL 脚本而不连接数据库
在线模式（run_migrations_online）：连接数据库执行迁移
"""
import sys
import os

# 将项目根目录加入 sys.path，保证可以正确导入 app 模块
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from logging.config import fileConfig
from alembic import context

# 导入 ORM 模型元数据以支持 autogenerate
from app.db.base import Base

config = context.config

# 从环境变量覆盖数据库连接地址
# DATABASE_URL 由 docker-compose.yml 的 env_file 注入，或由开发者在 shell 中 export
database_url = os.getenv("DATABASE_URL")
if database_url:
    config.set_main_option("sqlalchemy.url", database_url)

# 日志配置从 alembic.ini 读取
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# 设置 Alembic 迁移目标元数据（指向所有 ORM 模型的 Base.metadata）
target_metadata = Base.metadata


def run_migrations_offline() -> None:
    """离线模式：生成 SQL 迁移脚本，不连接数据库"""
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """在线模式：连接数据库执行迁移"""
    from sqlalchemy import create_engine

    connectable = create_engine(config.get_main_option("sqlalchemy.url"))

    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
        )

        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
