"""
FarmEye Guard v1.0 — API 依赖注入

提供 API Key 认证依赖注入和公共依赖导出。
"""
from fastapi import Header, HTTPException, Depends

from app.config import settings
from app.db.session import get_db

__all__ = [
    "verify_api_key",
    "get_db",
]


async def verify_api_key(
    x_api_key: str = Header(None),
) -> str | None:
    """
    API Key 认证依赖注入。

    从 X-Api-Key 请求头中读取密钥，与 settings.API_KEYS 中配置的
    逗号分隔密钥列表进行匹配。匹配成功则返回密钥值，失败则抛出 401 异常。
    当 settings.API_KEYS 为空字符串时，自动跳过认证（开发模式）。
    """
    if not settings.API_KEYS:
        return None

    valid_keys = [k.strip() for k in settings.API_KEYS.split(",") if k.strip()]

    if not x_api_key or x_api_key not in valid_keys:
        raise HTTPException(
            status_code=401,
            detail={
                "code": 1004,
                "message": "Invalid or missing API Key",
            },
        )

    return x_api_key
