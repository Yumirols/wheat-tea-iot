"""
FarmEye Guard v1.0 — 图片上传与获取 API 端点

提供图片上传和管理 REST 接口。
所有端点使用 API Key 认证。

设计参考：docs/1_system_architecture.md §4.7 图片存储规范
"""
import os
import random
import logging
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from fastapi.responses import FileResponse
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.api import deps
from app.config import settings
from app.db.session import get_db
from app.models.disease import DiseaseRecord

router = APIRouter(dependencies=[Depends(deps.verify_api_key)])
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# 常量定义
# ---------------------------------------------------------------------------

ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png"}
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10 MB
EXTENSION_MAP = {
    "image/jpeg": "jpg",
    "image/png": "png",
}

# 内存映射缓存：image_id -> 绝对路径（服务重启后丢失，仅用于运行时快速查找）
_image_path_cache: dict[str, str] = {}


# ---------------------------------------------------------------------------
# Pydantic Schema
# ---------------------------------------------------------------------------

class ImageUploadResponse(BaseModel):
    """图片上传响应"""
    image_id: str
    image_path: str
    file_size: int
    uploaded_at: datetime


# ---------------------------------------------------------------------------
# API Endpoints
# ---------------------------------------------------------------------------

@router.post("/image/upload")
async def upload_image(
    file: UploadFile = File(..., description="图片文件（jpg/png，最大 10MB）"),
    disease_record_id: Optional[int] = Form(
        None, description="关联的病虫害记录 ID"
    ),
    device_id: Optional[str] = Form(
        None, description="设备 ID（用于路径组织）"
    ),
    db: Session = Depends(get_db),
) -> dict:
    """
    上传图片。

    验证文件类型（仅 jpg/png），限制大小 10MB。
    按日期组织存储路径：{IMAGE_STORAGE_PATH}/YYYY/MM/DD/{image_id}.{ext}
    若提供 disease_record_id，更新对应记录的 image_path 字段。
    """
    # 1. 验证文件类型
    content_type = file.content_type or ""
    if content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=422,
            detail={
                "code": 1004,
                "message": "unsupported file type",
            },
        )

    # 2. 读取文件内容并验证大小
    file_data = await file.read()
    file_size = len(file_data)

    if file_size > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=422,
            detail={
                "code": 1005,
                "message": "file too large, max 10MB",
            },
        )

    # 3. 生成 image_id
    now = datetime.now()
    rand_part = f"{random.randint(0, 999):03d}"
    image_id = f"img_{now.strftime('%Y%m%d_%H%M%S')}_{rand_part}"
    ext = EXTENSION_MAP[content_type]

    # 4. 按日期组织存储路径
    date_path = now.strftime("%Y/%m/%d")
    storage_dir = os.path.join(settings.IMAGE_STORAGE_PATH, date_path)
    os.makedirs(storage_dir, exist_ok=True)

    filename = f"{image_id}.{ext}"
    absolute_path = os.path.join(storage_dir, filename)

    # 5. 写入文件
    with open(absolute_path, "wb") as f:
        f.write(file_data)

    # 记录路径映射
    _image_path_cache[image_id] = absolute_path

    uploaded_at = now
    logger.info(
        "Image uploaded: image_id=%s path=%s size=%d",
        image_id, absolute_path, file_size,
    )

    # 6. 若提供 disease_record_id，更新对应记录的 image_path
    if disease_record_id is not None:
        record = (
            db.query(DiseaseRecord)
            .filter(DiseaseRecord.id == disease_record_id)
            .first()
        )
        if not record:
            raise HTTPException(
                status_code=404,
                detail={
                    "code": 1001,
                    "message": "disease record not found",
                },
            )
        image_path = f"/images/{date_path}/{filename}"
        record.image_path = image_path
        db.commit()
        logger.info(
            "Linked image %s to disease_record id=%d",
            image_id, disease_record_id,
        )

    # 返回响应（图片路径使用可公开访问的 URL 风格路径）
    url_path = f"/images/{date_path}/{filename}"

    return {
        "code": 0,
        "message": "success",
        "data": {
            "image_id": image_id,
            "image_path": url_path,
            "file_size": file_size,
            "uploaded_at": uploaded_at,
        },
    }


@router.get("/image/{image_id}")
async def get_image(
    image_id: str,
) -> FileResponse:
    """
    获取图片。

    根据 image_id 查找文件并返回二进制流。
    Content-Type 根据文件扩展名自动判断。
    验证 image_id 不包含路径遍历字符。
    """
    # 安全防护：验证 image_id 不包含路径遍历字符
    if _contains_path_traversal(image_id):
        raise HTTPException(
            status_code=404,
            detail={
                "code": 1002,
                "message": "image not found",
                "data": None,
            },
        )

    # 从缓存中查找
    file_path = _image_path_cache.get(image_id)
    if file_path and os.path.isfile(file_path):
        media_type = _guess_media_type(file_path)
        return FileResponse(
            path=file_path,
            media_type=media_type,
            filename=os.path.basename(file_path),
        )

    # 缓存未命中 -> 首次查找存储目录（适用于服务重启后首次访问）
    resolved = _find_image_by_id(image_id)
    if resolved:
        _image_path_cache[image_id] = resolved
        media_type = _guess_media_type(resolved)
        return FileResponse(
            path=resolved,
            media_type=media_type,
            filename=os.path.basename(resolved),
        )

    # 图片不存在
    raise HTTPException(
        status_code=404,
        detail={
            "code": 1002,
            "message": "image not found",
            "data": None,
        },
    )


# ---------------------------------------------------------------------------
# 内部辅助函数
# ---------------------------------------------------------------------------

def _contains_path_traversal(path: str) -> bool:
    """检测路径中是否包含路径遍历字符。"""
    normalized = path.replace("\\", "/")
    return "../" in normalized or "..\\" in normalized or ".." in normalized.split("/")


def _guess_media_type(file_path: str) -> str:
    """根据文件扩展名猜测 MIME 类型。"""
    ext = os.path.splitext(file_path)[1].lower()
    return {
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".png": "image/png",
    }.get(ext, "application/octet-stream")


def _find_image_by_id(image_id: str) -> Optional[str]:
    """
    在 IMAGE_STORAGE_PATH 目录下查找匹配的图片文件。
    遍历子目录结构: YYYY/MM/DD/{image_id}.{ext}
    """
    if not os.path.isdir(settings.IMAGE_STORAGE_PATH):
        return None

    for root, _dirs, files in os.walk(settings.IMAGE_STORAGE_PATH):
        for filename in files:
            name, _ext = os.path.splitext(filename)
            if name == image_id:
                return os.path.join(root, filename)

    return None
