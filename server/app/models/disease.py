"""
FarmEye Guard v1.0 — DiseaseRecord ORM 模型

映射 disease_records 表，记录病虫害识别结果。
"""
from sqlalchemy import Column, BigInteger, String, SmallInteger, Numeric, DateTime, text

from app.db.base import Base


class DiseaseRecord(Base):
    """病虫害识别记录表（disease_records）"""

    __tablename__ = "disease_records"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    device_id = Column(String(64), nullable=False)
    timestamp = Column(DateTime, nullable=False, server_default=text("CURRENT_TIMESTAMP"))

    # 识别结果
    crop_type = Column(String(32), nullable=False)
    disease_type = Column(String(64), nullable=False)
    confidence = Column(Numeric(4, 3))
    severity = Column(String(16), nullable=False)  # Mild / Moderate / Severe
    severity_code = Column(SmallInteger, nullable=False)  # 1=Mild, 2=Moderate, 3=Severe

    # 联动分析
    linkage_risk_level = Column(String(16))  # low / medium / high
    linkage_detail = Column(String(512))

    # 关联资源
    image_path = Column(String(512))
    action_taken = Column(String(128))

    created_at = Column(DateTime, server_default=text("CURRENT_TIMESTAMP"))
