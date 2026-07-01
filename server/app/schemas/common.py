"""
FarmEye Guard v1.0 — 通用 Pydantic Schema

包含通用响应模型、分页参数和分页元数据。
"""
from typing import Generic, TypeVar, Optional
from pydantic import BaseModel

T = TypeVar("T")


class ResponseModel(BaseModel, Generic[T]):
    """通用 API 响应模型"""

    code: int
    message: str
    data: Optional[T] = None


class PaginationParams(BaseModel):
    """分页查询参数"""

    page: int = 1
    page_size: int = 20


class PaginationMeta(BaseModel):
    """分页元数据"""

    total: int
    page: int
    page_size: int
