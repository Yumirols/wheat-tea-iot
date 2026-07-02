"""
FarmEye Guard v1.0 — 图片管理 API 单元测试

覆盖用例 #32-#35：
  #32 test_upload_image           上传图片 → 200, image_id
  #33 test_upload_image_too_large 超过 10MB → 422
  #34 test_get_image              有效 image_id → 200 + 二进制流
  #35 test_get_image_not_found    无效 image_id → 404 + code=1002

测试策略：Mock 文件系统操作（os.makedirs、open），
使用临时文件测试图片获取。
"""
import os
import tempfile
from unittest.mock import patch, MagicMock, mock_open

import pytest


# =========================================================================
# 上传
# =========================================================================


@pytest.mark.asyncio
async def test_upload_image(async_client):
    """
    用例 #32：上传图片。

    使用 multipart 格式上传 jpg 图片，关联 disease_record_id=1。
    预期：
      - HTTP 200
      - code = 0
      - data 含 image_id / image_path / file_size / uploaded_at
    """
    # Mock 文件系统和 DB 查询
    with (
        patch("os.makedirs", return_value=None) as mock_makedirs,
        patch("builtins.open", mock_open()) as mock_file,
        patch("app.api.v1.image.DiseaseRecord") as mock_disease_model,
    ):
        mock_record = MagicMock()
        mock_record.id = 1
        mock_disease_model.query.return_value.filter.return_value.first.return_value = (
            mock_record
        )

        response = await async_client.post(
            "/api/v1/image/upload?disease_record_id=1",
            files={"file": ("test.jpg", b"fake_image_data", "image/jpeg")},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["code"] == 0
        assert "image_id" in data["data"]
        assert data["data"]["image_path"].startswith("/images/")
        assert data["data"]["file_size"] == len(b"fake_image_data")
        assert "uploaded_at" in data["data"]

        # 验证目录和文件写入被调用
        mock_makedirs.assert_called_once()
        mock_file.assert_called_once()


@pytest.mark.asyncio
async def test_upload_image_too_large(async_client):
    """
    用例 #33：上传超过 10MB 的文件。

    预期：HTTP 422（file too large）
    """
    large_data = b"x" * (11 * 1024 * 1024)  # 11MB

    response = await async_client.post(
        "/api/v1/image/upload",
        files={"file": ("large.jpg", large_data, "image/jpeg")},
    )

    assert response.status_code == 422
    data = response.json()
    # detail 中包含 code=1005 和 max 10MB 提示
    assert "detail" in data


# =========================================================================
# 获取
# =========================================================================


@pytest.mark.asyncio
async def test_get_image(async_client):
    """
    用例 #34：有效 image_id 获取图片。

    使用临时文件模拟已存储的图片。
    预期：
      - HTTP 200
      - Content-Type 为 image/jpeg
      - 返回二进制流
    """
    # 创建临时文件模拟已存储的图片
    tmp = tempfile.NamedTemporaryFile(suffix=".jpg", delete=False)
    try:
        tmp.write(b"fake_image_data_for_test")
        tmp.close()

        with patch.dict(
            "app.api.v1.image._image_path_cache",
            {"test_img_001": tmp.name},
            clear=True,
        ):
            response = await async_client.get("/api/v1/image/test_img_001")

            assert response.status_code == 200
            assert response.headers.get("content-type") == "image/jpeg"
            content = response.read()
            assert content == b"fake_image_data_for_test"
    finally:
        if os.path.exists(tmp.name):
            os.unlink(tmp.name)


@pytest.mark.asyncio
async def test_get_image_not_found(async_client):
    """
    用例 #35：无效 image_id 获取图片。

    图片不存在于缓存和磁盘。
    预期：
      - HTTP 404
      - detail.code = 1002
    """
    with (
        patch.dict("app.api.v1.image._image_path_cache", {}, clear=True),
        patch("os.path.isdir", return_value=False),
        patch("app.api.v1.image._find_image_by_id", return_value=None),
    ):
        response = await async_client.get("/api/v1/image/nonexistent_img")

        assert response.status_code == 404
        data = response.json()
        assert data["detail"]["code"] == 1002
        assert data["detail"]["message"] == "image not found"
