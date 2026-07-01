"""
FarmEye Guard v1.0 — Sensor ORM 模型

包含两张表：
- sensor_snapshot：环境数据快照（温度、湿度、光照、CO2、土壤NPK等）
- sensor_daily_aggregation：传感器日聚合数据
"""
from sqlalchemy import Column, BigInteger, String, Integer, SmallInteger, Numeric, DateTime, Date, UniqueConstraint

from app.db.base import Base


class SensorSnapshot(Base):
    """环境数据快照表（sensor_snapshot）"""

    __tablename__ = "sensor_snapshot"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    device_id = Column(String(64), nullable=False)
    mac_addr = Column(String(17))
    timestamp = Column(DateTime, nullable=False, server_default="CURRENT_TIMESTAMP")

    # 环境参数
    temperature = Column(Numeric(4, 1))
    humidity = Column(Numeric(4, 1))
    light = Column(Integer)
    co2 = Column(Integer)
    soil_n = Column(Numeric(5, 1))
    soil_p = Column(Numeric(5, 1))
    soil_k = Column(Numeric(5, 1))
    distance = Column(Integer)
    rssi = Column(SmallInteger)
    ip_addr = Column(String(16))
    alarm_flag = Column(Integer)

    created_at = Column(DateTime, server_default="CURRENT_TIMESTAMP")


class SensorDailyAggregation(Base):
    """传感器日聚合数据表（sensor_daily_aggregation）"""

    __tablename__ = "sensor_daily_aggregation"

    __table_args__ = (
        UniqueConstraint('device_id', 'agg_date', name='uq_sensor_daily_agg_device_date'),
    )

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    device_id = Column(String(64), nullable=False)
    agg_date = Column(Date, nullable=False)

    # 温度统计
    avg_temperature = Column(Numeric(4, 1))
    max_temperature = Column(Numeric(4, 1))
    min_temperature = Column(Numeric(4, 1))

    # 湿度统计
    avg_humidity = Column(Numeric(4, 1))
    max_humidity = Column(Numeric(4, 1))
    min_humidity = Column(Numeric(4, 1))

    # 光照统计
    avg_light = Column(Numeric(5, 1))
    max_light = Column(Integer)
    min_light = Column(Integer)

    # CO2 统计
    avg_co2 = Column(Numeric(6, 1))
    max_co2 = Column(Integer)
    min_co2 = Column(Integer)

    record_count = Column(Integer)

    created_at = Column(DateTime, server_default="CURRENT_TIMESTAMP")
