"""
FarmEye Guard v1.0 — SQLAlchemy Declarative Base

提供所有 ORM 模型的共享基类和 MetaData 命名约定。
"""
from sqlalchemy import MetaData
from sqlalchemy.orm import DeclarativeBase

# 表名和列名命名约定
convention = {
    "ix": "ix_%(column_0_label)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
}

metadata = MetaData(naming_convention=convention)


class Base(DeclarativeBase):
    """所有 ORM 模型的声明基类"""
    metadata = metadata
