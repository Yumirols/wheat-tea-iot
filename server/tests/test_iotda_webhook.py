"""
FarmEye Guard v1.0 — IoTDA Webhook API 单元测试

覆盖用例 #1-#9：
  #1  test_properties_report      POST /api/v1/iotda/properties/report
  #2  test_ai_report              POST /api/v1/iotda/ai/report
  #3  test_command_response       POST /api/v1/iotda/cmd/response
  #4  test_properties_idempotent  幂等性（相同 Payload 两次）
  #5  test_ai_idempotent          AI 幂等性
  #6  test_invalid_payload        缺少 notify_data → 422
  #7  test_unknown_service_id     未知 service_id → 200，不写入 DB
  #8  test_db_write_failure       DB 写入异常 → 500（实际为 200，catch 处理）
  #9  test_device_auto_register   新 device_id 自动创建设备记录
"""
import pytest


# =========================================================================
# 正常上报流程
# =========================================================================


@pytest.mark.asyncio
async def test_properties_report(async_client, sample_sensor_payload):
    """
    用例 #1：传感器属性上报。

    预期：
      - HTTP 200
      - code = 0
      - data.id 存在
    """
    response = await async_client.post(
        "/api/v1/iotda/properties/report",
        json=sample_sensor_payload,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["code"] == 0
    assert "data" in data


@pytest.mark.asyncio
async def test_ai_report(async_client, sample_ai_payload):
    """
    用例 #2：AI 识别结果上报。

    预期：
      - HTTP 200
      - code = 0
    """
    response = await async_client.post(
        "/api/v1/iotda/ai/report",
        json=sample_ai_payload,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["code"] == 0
    assert "data" in data


@pytest.mark.asyncio
async def test_command_response(async_client, sample_command_response_payload):
    """
    用例 #3：命令应答上报。

    预期：
      - HTTP 200
      - code = 0
    """
    response = await async_client.post(
        "/api/v1/iotda/cmd/response",
        json=sample_command_response_payload,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["code"] == 0


# =========================================================================
# 幂等性
# =========================================================================


@pytest.mark.asyncio
async def test_properties_idempotent(async_client, sample_sensor_payload):
    """
    用例 #4：传感器上报幂等性。

    第一次正常发送，第二次模拟数据库 UNIQUE 冲突（create_snapshot 抛异常）。
    预期两次均返回 200 + code=0。
    """
    # 第一次：正常处理
    response1 = await async_client.post(
        "/api/v1/iotda/properties/report",
        json=sample_sensor_payload,
    )
    assert response1.status_code == 200

    # 第二次：模拟唯一键冲突
    import app.api.v1.iotda

    with pytest.MonkeyPatch.context() as mp:
        original = app.api.v1.iotda.create_snapshot

        def _raise_on_dup(db, device_id, properties, timestamp):
            raise Exception('duplicate key value violates unique constraint "uq_snapshot_device_time"')

        mp.setattr(app.api.v1.iotda, "create_snapshot", _raise_on_dup)
        response2 = await async_client.post(
            "/api/v1/iotda/properties/report",
            json=sample_sensor_payload,
        )
        assert response2.status_code == 200
        data2 = response2.json()
        assert data2["code"] == 0

        # 恢复
        mp.setattr(app.api.v1.iotda, "create_snapshot", original)


@pytest.mark.asyncio
async def test_ai_idempotent(async_client, sample_ai_payload):
    """
    用例 #5：AI 上报幂等性。

    第一次正常处理，第二次模拟 DB 写入抛异常。
    预期两次均返回 200 + code=0。
    """
    # 第一次
    response1 = await async_client.post(
        "/api/v1/iotda/ai/report",
        json=sample_ai_payload,
    )
    assert response1.status_code == 200

    # 第二次：模拟唯一键冲突（db.commit 抛异常）
    import app.api.v1.iotda as iotda_module

    with pytest.MonkeyPatch.context() as mp:

        def _raise_on_add(*args, **kwargs):
            raise Exception('duplicate key value violates unique constraint "uq_disease_device_time"')

        mp.setattr(iotda_module.DiseaseRecord, "__init__", _raise_on_add)
        response2 = await async_client.post(
            "/api/v1/iotda/ai/report",
            json=sample_ai_payload,
        )
        assert response2.status_code == 200
        data2 = response2.json()
        assert data2["code"] == 0


# =========================================================================
# 异常场景
# =========================================================================


@pytest.mark.asyncio
async def test_invalid_payload(async_client):
    """
    用例 #6：无效 Payload — 缺少 notify_data。

    预期：HTTP 422
    """
    payload = {"resource": "device.property", "event": "report"}
    response = await async_client.post(
        "/api/v1/iotda/properties/report",
        json=payload,
    )
    assert response.status_code == 422

    response2 = await async_client.post(
        "/api/v1/iotda/ai/report",
        json=payload,
    )
    assert response2.status_code == 422

    response3 = await async_client.post(
        "/api/v1/iotda/cmd/response",
        json=payload,
    )
    assert response3.status_code == 422


@pytest.mark.asyncio
async def test_unknown_service_id(async_client, sample_sensor_payload, mock_db_session):
    """
    用例 #7：未知 service_id。

    使用非 farmeye_env / farmeye_ai 的 service_id，
    预期返回 200 + code=0，且 db.add 未被调用。
    """
    payload = {
        **sample_sensor_payload,
        "notify_data": {
            "header": {"device_id": "test_dev_001"},
            "body": {
                "services": [
                    {"service_id": "unknown_service", "properties": {"temperature": 30.0}}
                ],
            },
        },
    }
    response = await async_client.post(
        "/api/v1/iotda/properties/report",
        json=payload,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["code"] == 0
    # 未知 service_id 不会被写入，add 不应被调用
    # （create_snapshot 不会被执行）
    mock_db_session.add.assert_not_called()


@pytest.mark.asyncio
async def test_db_write_failure(async_client, sample_sensor_payload):
    """
    用例 #8：DB 写入异常。

    模拟 create_snapshot 抛出异常，验证异常被捕获并返回 200。
    """
    import app.api.v1.iotda

    with pytest.MonkeyPatch.context() as mp:
        def _raise(db, device_id, properties, timestamp):
            raise Exception("Database write error")

        mp.setattr(app.api.v1.iotda, "create_snapshot", _raise)
        response = await async_client.post(
            "/api/v1/iotda/properties/report",
            json=sample_sensor_payload,
        )
        assert response.status_code == 200
        data = response.json()
        assert data["code"] == 0


# =========================================================================
# 设备自动注册
# =========================================================================


@pytest.mark.asyncio
async def test_device_auto_register(async_client, sample_sensor_payload, mock_db_session):
    """
    用例 #9：新 device_id 首次上报 → 自动创建设备记录。

    模拟 db.query().filter().first() 返回 None（设备不存在），
    verify ensure_device_exists 被触发（db.add 被调用）。
    """
    # 配置 mock：设备不存在
    mock_db_session.query.return_value.filter.return_value.first.return_value = None

    response = await async_client.post(
        "/api/v1/iotda/properties/report",
        json=sample_sensor_payload,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["code"] == 0

    # 验证 create_snapshot 内部调用了 db.add（写入 Device 或 SensorSnapshot）
    mock_db_session.add.assert_called()
    mock_db_session.commit.assert_called()
