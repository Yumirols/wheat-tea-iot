"""
FarmEye Guard v1.0 — ControlLog 和 Device ORM 模型

包含两张表：
- control_logs：设备控制日志
- devices：设备注册信息
"""
from sqlalchemy import Column, BigInteger, String, Integer, SmallInteger, Boolean, DateTime, text

from app.db.base import Base


class ControlLog(Base):
    """设备控制日志表（control_logs）"""

    __tablename__ = "control_logs"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    device_id = Column(String(64), nullable=False)
    command_id = Column(String(64))
    timestamp = Column(DateTime, nullable=False, server_default=text("CURRENT_TIMESTAMP"))

    command = Column(String(64), nullable=False)
    source = Column(String(32), nullable=False)  # 'auto' / 'manual_app' / 'manual_pc'
    operator = Column(String(64))
    result_code = Column(Integer)
    result_msg = Column(String(255))

    created_at = Column(DateTime, server_default=text("CURRENT_TIMESTAMP"))


class Device(Base):
    """设备注册信息表（devices）"""

    __tablename__ = "devices"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    device_id = Column(String(64), nullable=False, unique=True)
    device_name = Column(String(128))
    mac_addr = Column(String(17))
    ip_addr = Column(String(16))
    registered_at = Column(DateTime, server_default=text("CURRENT_TIMESTAMP"))
    last_seen = Column(DateTime)
    online = Column(Boolean, default=False)

    created_at = Column(DateTime, server_default=text("CURRENT_TIMESTAMP"))
