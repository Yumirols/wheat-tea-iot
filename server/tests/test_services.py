"""
FarmEye Guard v1.0 — 业务逻辑服务层单元测试

覆盖 app/services 中的所有业务逻辑：
  - sensor_service
  - disease_service
  - command_service
  - advisory_service
  - iotda_client
  - data_retention
"""
import pytest
from datetime import datetime, date, timedelta
from unittest.mock import patch, MagicMock
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.ext.compiler import compiles
from sqlalchemy.types import BIGINT, BigInteger

from app.db.base import Base
from app.models import SensorSnapshot, SensorDailyAggregation, DiseaseRecord, ControlLog, Device
from app.services import sensor_service, disease_service, command_service, advisory_service, iotda_client, data_retention
from app.services.iotda_client import IotdaClientError


# 覆盖 SQLite 下 BIGINT 和 BigInteger 的编译规则为 INTEGER，确保 SQLite 主键能自动递增 (autoincrement)
@compiles(BIGINT, "sqlite")
@compiles(BigInteger, "sqlite")
def compile_bigint_sqlite(type_, compiler, **kw):
    return "INTEGER"


@pytest.fixture(name="db_session")
def db_session_fixture():
    """使用 SQLite 内存数据库进行隔离的单元测试"""
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    try:
        yield session
    finally:
        session.close()


# =========================================================================
# 1. iotda_client.py 单元测试
# =========================================================================

def test_iotda_client_error():
    """测试 IotdaClientError 的构造函数"""
    err = IotdaClientError("network error", 502)
    assert err.message == "network error"
    assert err.status_code == 502
    assert str(err) == "network error"


def test_iotda_send_command_unimplemented():
    """测试 _do_send_command 会抛出 NotImplementedError"""
    with pytest.raises(NotImplementedError):
        iotda_client._do_send_command("dev_001", "relay_on")


def test_iotda_send_command_mock_endpoint():
    """测试当设置 settings.IOTDA_ENDPOINT 时 send_command 逻辑"""
    with patch("app.services.iotda_client.settings") as mock_settings:
        mock_settings.IOTDA_ENDPOINT = "http://mock-iotda-platform"
        res = iotda_client.send_command("dev_001", "relay_on")
        assert "command_id" in res
        assert res["command_id"].startswith("mock_")


# =========================================================================
# 2. command_service.py 单元测试
# =========================================================================

def test_create_command_device_offline(db_session):
    """测试设备离线或不存在时下发命令被拒"""
    # 1. 设备不存在
    res = command_service.create_command(db_session, "dev_non_exist", "relay_on", "manual")
    assert res == {"status": "offline", "code": 1003}

    # 2. 设备存在但离线
    dev = Device(id=1, device_id="dev_offline", online=False)
    db_session.add(dev)
    db_session.commit()
    res = command_service.create_command(db_session, "dev_offline", "relay_on", "manual")
    assert res == {"status": "offline", "code": 1003}


def test_create_command_iotda_exception(db_session):
    """测试 IoTDA 发送命令异常时返回失败状态"""
    dev = Device(id=1, device_id="dev_online", online=True)
    db_session.add(dev)
    db_session.commit()

    with patch("app.services.iotda_client.send_command", side_effect=Exception("API limit exceeded")):
        res = command_service.create_command(db_session, "dev_online", "relay_on", "manual")
        assert res["status"] == "failed"
        assert res["code"] == 1002
        assert "API limit exceeded" in res["message"]


def test_create_command_success(db_session):
    """测试命令下发成功并记录控制日志"""
    dev = Device(id=1, device_id="dev_online", online=True)
    db_session.add(dev)
    db_session.commit()

    with patch("app.services.iotda_client.send_command", return_value={"command_id": "cmd_mock_123"}):
        res = command_service.create_command(db_session, "dev_online", "relay_on", "manual", "admin_01")
        assert res["status"] == "sent"
        assert res["command_id"] == "cmd_mock_123"
        assert res["device_id"] == "dev_online"
        assert res["command"] == "relay_on"

        # 检查数据库是否生成了 ControlLog
        log = db_session.query(ControlLog).filter(ControlLog.command_id == "cmd_mock_123").first()
        assert log is not None
        assert log.device_id == "dev_online"
        assert log.command == "relay_on"
        assert log.source == "manual"
        assert log.operator == "admin_01"


def test_get_command_logs(db_session):
    """测试分页及多条件查询控制日志"""
    base_time = datetime(2026, 7, 10, 12, 0, 0)
    log1 = ControlLog(id=1, device_id="dev1", command_id="c1", command="relay_on", source="manual", timestamp=base_time)
    log2 = ControlLog(id=2, device_id="dev1", command_id="c2", command="relay_off", source="auto", timestamp=base_time + timedelta(hours=1))
    log3 = ControlLog(id=3, device_id="dev2", command_id="c3", command="relay_on", source="manual", timestamp=base_time + timedelta(hours=2))
    db_session.add_all([log1, log2, log3])
    db_session.commit()

    # 1. 筛选特定设备
    records, total = command_service.get_command_logs(db_session, device_id="dev1")
    assert total == 2
    assert records[0].command_id == "c2"  # 最新优先

    # 2. 筛选特定 source
    records, total = command_service.get_command_logs(db_session, source="auto")
    assert total == 1
    assert records[0].command_id == "c2"

    # 3. 筛选时间范围
    records, total = command_service.get_command_logs(
        db_session,
        start=base_time + timedelta(minutes=30),
        end=base_time + timedelta(hours=1, minutes=30)
    )
    assert total == 1
    assert records[0].command_id == "c2"


# =========================================================================
# 3. sensor_service.py 单元测试
# =========================================================================

def test_get_latest_snapshots(db_session):
    """测试查询最新传感器快照记录"""
    t1 = datetime(2026, 7, 10, 10, 0, 0)
    t2 = datetime(2026, 7, 10, 11, 0, 0)

    snap1 = SensorSnapshot(id=1, device_id="dev1", timestamp=t1, temperature=20.0)
    snap2 = SensorSnapshot(id=2, device_id="dev1", timestamp=t2, temperature=22.0)
    snap3 = SensorSnapshot(id=3, device_id="dev2", timestamp=t2, temperature=25.0)
    db_session.add_all([snap1, snap2, snap3])
    db_session.commit()

    # 1. 查询指定设备最新数据
    res = sensor_service.get_latest_snapshots(db_session, device_id="dev1")
    assert len(res) == 1
    assert float(res[0].temperature) == 22.0

    # 2. 查询不存在设备的最新数据
    res = sensor_service.get_latest_snapshots(db_session, device_id="dev_unknown")
    assert res == []

    # 3. 查询所有设备的最新数据
    res = sensor_service.get_latest_snapshots(db_session)
    assert len(res) == 2
    assert res[0].device_id == "dev1"
    assert float(res[0].temperature) == 22.0
    assert res[1].device_id == "dev2"
    assert float(res[1].temperature) == 25.0


def test_get_sensor_history(db_session):
    """测试分页查询传感器历史数据"""
    base_time = datetime(2026, 7, 10, 12, 0, 0)
    for i in range(5):
        snap = SensorSnapshot(id=i+1, device_id="dev1", timestamp=base_time + timedelta(minutes=i))
        db_session.add(snap)
    db_session.commit()

    # 带时间区间的分页查询
    records, total = sensor_service.get_sensor_history(
        db_session,
        device_id="dev1",
        start=base_time + timedelta(minutes=1),
        end=base_time + timedelta(minutes=3),
        page=1,
        page_size=2
    )
    assert total == 3  # 在 minutes=1, 2, 3 的 3 条记录
    assert len(records) == 2
    assert records[0].timestamp == base_time + timedelta(minutes=3)  # DESC order


def test_get_daily_aggregation(db_session):
    """测试分页查询日聚合数据"""
    d1 = date(2026, 7, 1)
    d2 = date(2026, 7, 2)
    agg1 = SensorDailyAggregation(id=1, device_id="dev1", agg_date=d1, avg_temperature=20.0)
    agg2 = SensorDailyAggregation(id=2, device_id="dev1", agg_date=d2, avg_temperature=22.0)
    db_session.add_all([agg1, agg2])
    db_session.commit()

    records, total = sensor_service.get_daily_aggregation(
        db_session,
        device_id="dev1",
        start=d1,
        end=d2,
        page=1,
        page_size=1
    )
    assert total == 2
    assert len(records) == 1
    assert records[0].agg_date == d2  # DESC order


def test_create_snapshot(db_session):
    """测试创建传感器数据快照并自动注册新设备"""
    now = datetime.utcnow()
    properties = {
        "temperature": 25.5,
        "humidity": 60.2,
        "light": 1000,
        "co2": 450,
        "mac_addr": "00:11:22:33:44:55"
    }
    
    snap = sensor_service.create_snapshot(db_session, "dev_new", properties, now)
    assert snap.device_id == "dev_new"
    assert float(snap.temperature) == 25.5
    assert snap.mac_addr == "00:11:22:33:44:55"
    
    # 验证新设备是否已自动注册
    device = db_session.query(Device).filter(Device.device_id == "dev_new").first()
    assert device is not None
    assert device.mac_addr == "00:11:22:33:44:55"
    assert device.online is True


def test_ensure_device_exists_updates_last_seen(db_session):
    """测试 ensure_device_exists 在设备已存在时更新其最后在线时间"""
    # 创建已存在的离线设备
    dev = Device(id=1, device_id="dev_exist", online=False, last_seen=datetime(2026, 1, 1))
    db_session.add(dev)
    db_session.commit()
    
    # 执行 ensure_device_exists
    device = sensor_service.ensure_device_exists(db_session, "dev_exist", "00:11:22:33:44:55")
    assert device.online is True
    assert device.last_seen > datetime(2026, 1, 1)



# =========================================================================
# 4. disease_service.py 单元测试
# =========================================================================

def test_get_disease_records(db_session):
    """测试分页及多条件查询病虫害记录"""
    base_time = datetime(2026, 7, 10, 12, 0, 0)
    rec1 = DiseaseRecord(id=1, device_id="dev1", crop_type="wheat", disease_type="rust", severity="Mild", severity_code=1, timestamp=base_time)
    rec2 = DiseaseRecord(id=2, device_id="dev1", crop_type="wheat", disease_type="rust", severity="Moderate", severity_code=2, timestamp=base_time + timedelta(hours=1))
    rec3 = DiseaseRecord(id=3, device_id="dev2", crop_type="tea", disease_type="anthracnose", severity="Severe", severity_code=3, timestamp=base_time + timedelta(hours=2))
    db_session.add_all([rec1, rec2, rec3])
    db_session.commit()

    # 各项条件匹配筛选
    records, total = disease_service.get_disease_records(
        db_session,
        device_id="dev1",
        crop_type="wheat",
        disease_type="rust",
        severity="Moderate",
        start=base_time + timedelta(minutes=30),
        end=base_time + timedelta(hours=1, minutes=30)
    )
    assert total == 1
    assert records[0].severity == "Moderate"


def test_get_disease_stats(db_session):
    """测试病虫害统计聚合函数"""
    # 1. 空数据库情况
    stats = disease_service.get_disease_stats(db_session)
    assert stats["total_detections"] == 0
    assert stats["by_crop"] == {}

    # 2. 插入部分统计数据
    rec1 = DiseaseRecord(id=1, device_id="dev1", crop_type="wheat", disease_type="rust", severity="Mild", severity_code=1, timestamp=datetime(2026, 7, 10, 12, 0))
    rec2 = DiseaseRecord(id=2, device_id="dev2", crop_type="wheat", disease_type="rust", severity="Moderate", severity_code=2, timestamp=datetime(2026, 7, 10, 13, 0))
    rec3 = DiseaseRecord(id=3, device_id="dev2", crop_type="tea", disease_type="anthracnose", severity="Severe", severity_code=3, timestamp=datetime(2026, 7, 10, 14, 0))
    db_session.add_all([rec1, rec2, rec3])
    db_session.commit()

    # 3. 不加时间范围
    stats = disease_service.get_disease_stats(db_session)
    assert stats["total_detections"] == 3
    assert stats["by_crop"] == {"wheat": 2, "tea": 1}
    assert stats["by_severity"] == {"Mild": 1, "Moderate": 1, "Severe": 1}
    assert stats["by_disease"] == {"rust": 2, "anthracnose": 1}

    # 4. 加时间范围
    stats_time = disease_service.get_disease_stats(db_session, start=datetime(2026, 7, 10, 12, 30), end=datetime(2026, 7, 10, 14, 30))
    assert stats_time["total_detections"] == 2
    assert stats_time["by_crop"] == {"wheat": 1, "tea": 1}


def test_get_heatmap_data(db_session):
    """测试热力图数据及概要计算"""
    rec1 = DiseaseRecord(id=1, device_id="dev1", crop_type="wheat", disease_type="rust", severity="Mild", severity_code=1, timestamp=datetime(2026, 7, 10, 12, 0))
    rec2 = DiseaseRecord(id=2, device_id="dev2", crop_type="wheat", disease_type="rust", severity="Moderate", severity_code=2, timestamp=datetime(2026, 7, 10, 13, 0))
    db_session.add_all([rec1, rec2])
    db_session.commit()

    res = disease_service.get_heatmap_data(db_session)
    assert res["summary"]["total_records"] == 2
    assert res["summary"]["active_disease_types"] == 1
    assert res["summary"]["affected_devices"] == 2
    assert len(res["heatmap_points"]) == 2


# =========================================================================
# 5. advisory_service.py 单元测试
# =========================================================================

def test_evaluate_linkage():
    """测试 evaluate_linkage 的多种环境-病虫害联动匹配规则"""
    detection = DiseaseRecord(disease_type="rust")
    
    # 1. 湿度和温度都满足 (High Risk)
    env_high = SensorSnapshot(temperature=20.0, humidity=90.0)
    res_high = advisory_service.evaluate_linkage(detection, env_high)
    assert res_high["risk_level"] == "high"
    assert len(res_high["matched_conditions"]) == 2

    # 2. 只有温度满足 (Medium Risk)
    env_med = SensorSnapshot(temperature=20.0, humidity=50.0)
    res_med = advisory_service.evaluate_linkage(detection, env_med)
    assert res_med["risk_level"] == "medium"
    assert len(res_med["matched_conditions"]) == 1

    # 3. 都不满足 (Low Risk)
    env_low = SensorSnapshot(temperature=10.0, humidity=50.0)
    res_low = advisory_service.evaluate_linkage(detection, env_low)
    assert res_low["risk_level"] == "low"
    assert len(res_low["matched_conditions"]) == 0

    # 4. 未知病虫害
    unknown_detection = DiseaseRecord(disease_type="unknown_pest")
    res_unknown = advisory_service.evaluate_linkage(unknown_detection, env_high)
    assert res_unknown["risk_level"] == "low"
    assert res_unknown["recommendation"] == "未知病虫害类型（unknown_pest），无法进行联动分析，建议保持常规监测。"


def test_build_recommendation():
    """测试中英文建议文本拼接"""
    rec_low = advisory_service._build_recommendation("rust", "锈病", "low", [])
    assert rec_low.startswith("当前环境条件对")

    rec_med = advisory_service._build_recommendation("rust", "锈病", "medium", ["湿度高"])
    assert "有利于" in rec_med
    assert "湿度高" in rec_med

    rec_high = advisory_service._build_recommendation("rust", "锈病", "high", ["湿度高", "温度适宜"])
    assert "非常有利于" in rec_high
    assert "立即采取防治措施" in rec_high


def test_generate_advisory():
    """测试根据决策规则矩阵生成防治建议"""
    # 未知病害
    detection_unknown = DiseaseRecord(disease_type="unknown")
    res = advisory_service.generate_advisory(detection_unknown)
    assert res["action"] == "manual_inspect"
    assert "unknown" in res["description"]

    # 已知病害 - severity 1 (轻度)
    detection_rust = DiseaseRecord(disease_type="rust", severity_code=1)
    res = advisory_service.generate_advisory(detection_rust)
    assert res["action"] == "manual_inspect"
    assert res["description"] == advisory_service.DISEASE_CONFIG["rust"]["sev1_desc"]

    # 已知病害 - severity 2 (中度), 环境未触发
    detection_rust_sev2 = DiseaseRecord(disease_type="rust", severity_code=2)
    res_not_triggered = advisory_service.generate_advisory(detection_rust_sev2, linkage={"matched_conditions": []})
    assert res_not_triggered["action"] == "manual_inspect"
    assert res_not_triggered["description"] == advisory_service.DISEASE_CONFIG["rust"]["sev2_not_triggered_desc"]

    # 已知病害 - severity 2 (中度), 环境触发
    res_triggered = advisory_service.generate_advisory(detection_rust_sev2, linkage={"matched_conditions": ["humidity"]})
    assert res_triggered["action"] == "spray_fungicide"
    assert res_triggered["description"] == advisory_service.DISEASE_CONFIG["rust"]["sev2_triggered_desc"]

    # 已知病害 - severity 3 (重度)
    detection_rust_severe = DiseaseRecord(disease_type="rust", severity_code=3)
    res = advisory_service.generate_advisory(detection_rust_severe)
    assert res["action"] == "spray_fungicide"
    assert res["auto_action_triggered"] is True
    assert res["auto_action"] == "spray ON"
    assert res["description"] == advisory_service.DISEASE_CONFIG["rust"]["sev3_desc"]

    # 未知 severity code
    detection_rust_weird = DiseaseRecord(disease_type="rust", severity_code=99)
    res = advisory_service.generate_advisory(detection_rust_weird)
    assert res["action"] == "manual_inspect"
    assert "99" in res["description"]


def test_get_advisory(db_session):
    """测试 get_advisory 汇总获取端到端分析"""
    # 1. 数据库中完全没有检测记录
    res_none = advisory_service.get_advisory(db_session, device_id="dev1")
    assert res_none["latest_detection"] is None

    # 2. 插入只有检测但没有传感器数据的记录
    now = datetime.utcnow()
    rec = DiseaseRecord(id=1, device_id="dev1", crop_type="wheat", disease_type="rust", severity="Moderate", severity_code=2, timestamp=now)
    db_session.add(rec)
    db_session.commit()

    res_only_det = advisory_service.get_advisory(db_session, device_id="dev1", window_minutes=60)
    assert res_only_det["latest_detection"] is not None
    assert res_only_det["current_env"] is None
    assert res_only_det["env_disease_linkage"] is None
    assert res_only_det["advisory"]["action"] == "manual_inspect"  # 环境未触发

    # 3. 插入满足环境条件的传感器快照，并再次运行
    snap = SensorSnapshot(id=1, device_id="dev1", temperature=22.0, humidity=90.0, timestamp=now)
    db_session.add(snap)
    db_session.commit()

    # 传入显式 start / end 范围
    res_both = advisory_service.get_advisory(db_session, device_id="dev1", start=now - timedelta(minutes=10), end=now + timedelta(minutes=10))
    assert res_both["latest_detection"] is not None
    assert res_both["current_env"] is not None
    assert res_both["env_disease_linkage"]["risk_level"] == "high"
    assert res_both["advisory"]["action"] == "spray_fungicide"

    # 验证是否反写并提交到数据库
    db_session.refresh(rec)
    assert rec.linkage_risk_level == "high"
    assert rec.linkage_detail is not None


# =========================================================================
# 6. data_retention.py 单元测试
# =========================================================================

def test_cleanup_expired_data(db_session):
    """测试数据清理及聚合任务"""
    with patch("app.services.data_retention.SessionLocal") as mock_session_local:
        mock_session_local.return_value = db_session

        # 插入过期及不过期的测试数据
        # 默认设置: sensor days=30, control days=90
        now = datetime.utcnow()
        expired_sensor_ts = now - timedelta(days=35)
        recent_sensor_ts = now - timedelta(days=10)
        expired_control_ts = now - timedelta(days=95)
        recent_control_ts = now - timedelta(days=20)

        # 聚合所用的过期 sensor_snapshot
        s1 = SensorSnapshot(id=1, device_id="dev1", timestamp=expired_sensor_ts, temperature=20.0, humidity=60.0, light=100, co2=400)
        s2 = SensorSnapshot(id=2, device_id="dev1", timestamp=expired_sensor_ts - timedelta(hours=1), temperature=30.0, humidity=80.0, light=200, co2=500)
        s3 = SensorSnapshot(id=3, device_id="dev2", timestamp=expired_sensor_ts, temperature=15.0, humidity=40.0, light=50, co2=300)
        # 最近不过期的 snapshot
        s4 = SensorSnapshot(id=4, device_id="dev1", timestamp=recent_sensor_ts, temperature=25.0)

        # 过期及不过期的 control_logs
        c1 = ControlLog(id=1, device_id="dev1", command_id="c_exp", command="relay_on", source="manual", timestamp=expired_control_ts)
        c2 = ControlLog(id=2, device_id="dev1", command_id="c_rec", command="relay_off", source="auto", timestamp=recent_control_ts)

        db_session.add_all([s1, s2, s3, s4, c1, c2])
        db_session.commit()

        # 运行清理任务
        data_retention.cleanup_expired_data()

        # 1. 验证过期 sensor_snapshot 是否已被删除，不过期的是否保留
        snaps = db_session.query(SensorSnapshot).all()
        assert len(snaps) == 1
        assert snaps[0].timestamp == recent_sensor_ts

        # 2. 验证过期 control_logs 是否已被删除，不过期的是否保留
        logs = db_session.query(ControlLog).all()
        assert len(logs) == 1
        assert logs[0].command_id == "c_rec"

        # 3. 验证是否生成了日聚合数据 SensorDailyAggregation
        aggs = db_session.query(SensorDailyAggregation).order_by(SensorDailyAggregation.device_id).all()
        assert len(aggs) == 2
        # dev1 聚合结果
        assert aggs[0].device_id == "dev1"
        assert float(aggs[0].avg_temperature) == 25.0  # (20 + 30) / 2
        assert float(aggs[0].max_temperature) == 30.0
        assert float(aggs[0].min_temperature) == 20.0
        assert aggs[0].record_count == 2
        
        # dev2 聚合结果
        assert aggs[1].device_id == "dev2"
        assert float(aggs[1].avg_temperature) == 15.0
        assert aggs[1].record_count == 1


def test_cleanup_expired_data_rollback():
    """测试数据清理遇到异常时触发事务回滚"""
    mock_db = MagicMock()
    mock_db.execute.side_effect = Exception("SQLite internal lock error")
    with patch("app.services.data_retention.SessionLocal") as mock_session_local:
        mock_session_local.return_value = mock_db

        with pytest.raises(Exception) as exc_info:
            data_retention.cleanup_expired_data()

        assert "SQLite internal lock error" in str(exc_info.value)
        mock_db.rollback.assert_called_once()
        mock_db.close.assert_called_once()
