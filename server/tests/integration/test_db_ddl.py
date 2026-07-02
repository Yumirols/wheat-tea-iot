"""
FarmEye Guard v1.0 — DDL / 索引验证集成测试

验证数据库表的创建、列结构、UNIQUE 约束和索引的正确性。

测试前提：
  - pytest --run-integration 选项已启用
  - PostgreSQL 容器运行中

验证目标（对应 init/01_create_tables.sql）：
  - 全部 5 个表的存在性
  - 所有 UNIQUE 索引和普通索引
  - 列定义和数据类型
"""
import pytest
from sqlalchemy import inspect, text
from sqlalchemy.orm import Session


# ===========================================================================
# 表存在性验证
# ===========================================================================


@pytest.mark.integration
class TestTableExistence:
    """验证全部 5 个表是否已正确创建。"""

    EXPECTED_TABLES = {
        "sensor_snapshot",
        "disease_records",
        "control_logs",
        "devices",
        "sensor_daily_aggregation",
    }

    @pytest.mark.slow
    def test_all_tables_exist(self, db_session: Session) -> None:
        """用例 1: 查询 information_schema.tables，验证 5 个表全部存在。"""
        inspector = inspect(db_session.bind)
        table_names = set(inspector.get_table_names())
        missing = self.EXPECTED_TABLES - table_names
        assert not missing, f"Missing tables: {missing}"
        assert table_names.issuperset(self.EXPECTED_TABLES)

    def test_sensor_snapshot_columns(self, db_session: Session) -> None:
        """验证 sensor_snapshot 表的列定义。"""
        inspector = inspect(db_session.bind)
        columns = {col["name"]: col for col in inspector.get_columns("sensor_snapshot")}

        expected = {
            "id", "device_id", "mac_addr", "timestamp",
            "temperature", "humidity", "light", "co2",
            "soil_n", "soil_p", "soil_k", "distance",
            "rssi", "ip_addr", "alarm_flag", "created_at",
        }
        assert set(columns.keys()) == expected, (
            f"Column mismatch: extra={set(columns.keys()) - expected}, "
            f"missing={expected - set(columns.keys())}"
        )

    def test_disease_records_columns(self, db_session: Session) -> None:
        """验证 disease_records 表的列定义。"""
        inspector = inspect(db_session.bind)
        columns = {col["name"]: col for col in inspector.get_columns("disease_records")}

        expected = {
            "id", "device_id", "timestamp",
            "crop_type", "disease_type", "confidence",
            "severity", "severity_code",
            "linkage_risk_level", "linkage_detail",
            "image_path", "action_taken", "created_at",
        }
        assert set(columns.keys()) == expected

    def test_control_logs_columns(self, db_session: Session) -> None:
        """验证 control_logs 表的列定义。"""
        inspector = inspect(db_session.bind)
        columns = {col["name"]: col for col in inspector.get_columns("control_logs")}

        expected = {
            "id", "device_id", "command_id", "timestamp",
            "command", "source", "operator",
            "result_code", "result_msg", "created_at",
        }
        assert set(columns.keys()) == expected

    def test_devices_columns(self, db_session: Session) -> None:
        """验证 devices 表的列定义。"""
        inspector = inspect(db_session.bind)
        columns = {col["name"]: col for col in inspector.get_columns("devices")}

        expected = {
            "id", "device_id", "device_name", "mac_addr",
            "ip_addr", "registered_at", "last_seen",
            "online", "created_at",
        }
        assert set(columns.keys()) == expected

    def test_sensor_daily_aggregation_columns(self, db_session: Session) -> None:
        """验证 sensor_daily_aggregation 表的列定义。"""
        inspector = inspect(db_session.bind)
        columns = {
            col["name"]: col
            for col in inspector.get_columns("sensor_daily_aggregation")
        }

        expected = {
            "id", "device_id", "agg_date",
            "avg_temperature", "max_temperature", "min_temperature",
            "avg_humidity", "max_humidity", "min_humidity",
            "avg_light", "max_light", "min_light",
            "avg_co2", "max_co2", "min_co2",
            "record_count", "created_at",
        }
        assert set(columns.keys()) == expected


# ===========================================================================
# 索引验证
# ===========================================================================


@pytest.mark.integration
class TestIndexExistence:
    """验证所有 UNIQUE 索引和普通索引的存在性。"""

    def _get_indexes(self, db_session: Session, table_name: str) -> list[dict]:
        """获取指定表的所有索引信息。"""
        inspector = inspect(db_session.bind)
        return inspector.get_indexes(table_name)

    def _find_index(self, indexes: list[dict], name: str) -> dict | None:
        """按名称查找索引。"""
        for idx in indexes:
            if idx["name"] == name:
                return idx
        return None

    def test_unique_index_sensor_device_time(self, db_session: Session) -> None:
        """验证 sensor_snapshot 上 idx_sensor_device_time UNIQUE 索引存在。"""
        indexes = self._get_indexes(db_session, "sensor_snapshot")
        idx = self._find_index(indexes, "idx_sensor_device_time")
        assert idx is not None, "Missing UNIQUE index idx_sensor_device_time"
        assert idx["unique"] is True
        assert idx["column_names"] == ["device_id", "timestamp"]

    def test_unique_index_disease_device_time(self, db_session: Session) -> None:
        """验证 disease_records 上 idx_disease_device_time UNIQUE 索引存在。"""
        indexes = self._get_indexes(db_session, "disease_records")
        idx = self._find_index(indexes, "idx_disease_device_time")
        assert idx is not None, "Missing UNIQUE index idx_disease_device_time"
        assert idx["unique"] is True
        assert idx["column_names"] == ["device_id", "timestamp", "disease_type"]

    def test_unique_index_control_command_id(self, db_session: Session) -> None:
        """验证 control_logs 上 idx_control_command_id 部分 UNIQUE 索引存在。"""
        indexes = self._get_indexes(db_session, "control_logs")
        idx = self._find_index(indexes, "idx_control_command_id")
        assert idx is not None, "Missing UNIQUE index idx_control_command_id"
        assert idx["unique"] is True
        # 部分索引: WHERE command_id IS NOT NULL
        # SQLAlchemy inspector 不返回 predicate 信息，此处仅验证索引名和唯一性

    def test_index_control_device_time(self, db_session: Session) -> None:
        """验证 control_logs 上 idx_control_device_time 索引存在。"""
        indexes = self._get_indexes(db_session, "control_logs")
        idx = self._find_index(indexes, "idx_control_device_time")
        assert idx is not None, "Missing index idx_control_device_time"
        assert idx["column_names"] == ["device_id", "timestamp"]

    def test_index_devices_device_id(self, db_session: Session) -> None:
        """验证 devices 上 idx_devices_device_id 索引存在。"""
        indexes = self._get_indexes(db_session, "devices")
        idx = self._find_index(indexes, "idx_devices_device_id")
        assert idx is not None, "Missing index idx_devices_device_id"
        assert idx["column_names"] == ["device_id"]

    def test_index_agg_device_date(self, db_session: Session) -> None:
        """验证 sensor_daily_aggregation 上 idx_agg_device_date 索引存在。"""
        indexes = self._get_indexes(db_session, "sensor_daily_aggregation")
        idx = self._find_index(indexes, "idx_agg_device_date")
        assert idx is not None, "Missing index idx_agg_device_date"
        assert idx["column_names"] == ["device_id", "agg_date"]

    def test_devices_device_id_unique(self, db_session: Session) -> None:
        """验证 devices.device_id 有 UNIQUE 约束。

        此约束由 ORM 模型定义（unique=True），会在数据库中创建 UNIQUE 索引。
        名称遵循 naming_convention: uq_devices_device_id。
        """
        indexes = self._get_indexes(db_session, "devices")
        unique_device_id = [
            idx for idx in indexes
            if idx["unique"] and "device_id" in idx["column_names"]
        ]
        assert len(unique_device_id) >= 1, (
            "No UNIQUE constraint on devices.device_id"
        )

    def test_daily_agg_unique_constraint(self, db_session: Session) -> None:
        """验证 sensor_daily_aggregation 上 (device_id, agg_date) 有 UNIQUE 约束。

        此约束由 ORM 模型定义（UniqueConstraint）。
        """
        indexes = self._get_indexes(db_session, "sensor_daily_aggregation")
        unique_agg = [
            idx for idx in indexes
            if idx["unique"]
            and set(idx["column_names"]) == {"device_id", "agg_date"}
        ]
        assert len(unique_agg) >= 1, (
            "No UNIQUE constraint on sensor_daily_aggregation(device_id, agg_date)"
        )


# ===========================================================================
# 约束执行验证
# ===========================================================================


@pytest.mark.integration
class TestConstraintEnforcement:
    """验证 UNIQUE 约束在 DB 层面正确执行。"""

    @pytest.mark.slow
    def test_sensor_unique_violation(self, db_session: Session) -> None:
        """用例: 插入重复 (device_id, timestamp) 应触发唯一约束错误。"""
        from app.models.sensor import SensorSnapshot
        from datetime import datetime
        from sqlalchemy.exc import IntegrityError

        ts = datetime(2026, 7, 2, 12, 0, 0)

        # 第一次插入成功
        s1 = SensorSnapshot(device_id="unique_test_dev", timestamp=ts, temperature=25.0)
        db_session.add(s1)
        db_session.commit()

        # 第二次插入相同 (device_id, timestamp) 应失败
        s2 = SensorSnapshot(device_id="unique_test_dev", timestamp=ts, temperature=26.0)
        db_session.add(s2)
        with pytest.raises(IntegrityError):
            db_session.commit()

        db_session.rollback()

    @pytest.mark.slow
    def test_device_unique_violation(self, db_session: Session) -> None:
        """用例: 插入重复 device_id 应触发唯一约束错误。"""
        from app.models.control import Device
        from sqlalchemy.exc import IntegrityError

        d1 = Device(device_id="dup_dev_001", device_name="First")
        db_session.add(d1)
        db_session.commit()

        d2 = Device(device_id="dup_dev_001", device_name="Duplicate")
        db_session.add(d2)
        with pytest.raises(IntegrityError):
            db_session.commit()

        db_session.rollback()

    def test_control_log_null_command_id(self, db_session: Session) -> None:
        """用例: command_id 为 NULL 的记录可以重复插入（部分索引特性）。"""
        from app.models.control import ControlLog

        log1 = ControlLog(
            device_id="ctrl_dev",
            command="spray ON",
            source="auto",
            command_id=None,
        )
        db_session.add(log1)
        db_session.commit()

        log2 = ControlLog(
            device_id="ctrl_dev",
            command="spray OFF",
            source="manual_app",
            command_id=None,
        )
        db_session.add(log2)
        db_session.commit()

        assert log2.id != log1.id, "NULL command_id records should coexist"


# ===========================================================================
# 列数据类型验证
# ===========================================================================


@pytest.mark.integration
class TestColumnTypes:
    """验证关键列的数据类型。"""

    def test_sensor_decimal_precision(self, db_session: Session) -> None:
        """验证 sensor_snapshot 中 Decimal(4,1) 字段的精度。"""
        from app.models.sensor import SensorSnapshot

        s = SensorSnapshot(
            device_id="decimal_test",
            timestamp="2026-07-02T12:00:00",
            temperature=25.5,    # Numeric(4,1): 总4位, 小数1位
            humidity=60.2,       # Numeric(4,1)
        )
        db_session.add(s)
        db_session.commit()

        # 读取验证
        result = db_session.query(SensorSnapshot).filter_by(
            device_id="decimal_test"
        ).first()
        assert float(result.temperature) == 25.5
        assert float(result.humidity) == 60.2

    def test_severity_code_smallint(self, db_session: Session) -> None:
        """验证 disease_records.severity_code 为 SMALLINT。"""
        from app.models.disease import DiseaseRecord

        r = DiseaseRecord(
            device_id="type_test",
            timestamp="2026-07-02T12:00:00",
            crop_type="wheat",
            disease_type="rust",
            severity="Severe",
            severity_code=3,
        )
        db_session.add(r)
        db_session.commit()

        result = db_session.query(DiseaseRecord).filter_by(
            device_id="type_test"
        ).first()
        assert result.severity_code == 3
        assert isinstance(result.severity_code, int)
