"""
FarmEye Guard v1.0 — Pydantic Settings 配置管理

所有配置项从环境变量读取，支持 .env 文件加载。
环境变量来源优先级：显式环境变量 > .env 文件 > 默认值。
"""
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """应用配置类，所有配置项从环境变量读取"""

    model_config = SettingsConfigDict(env_file=".env")

    # --- Database ---
    DATABASE_URL: str = "postgresql+psycopg2://farmeye:farmeye_pwd@localhost:5432/farmeye_db"

    # --- Huawei IoTDA ---
    IOTDA_ENDPOINT: str = ""
    IOTDA_PROJECT_ID: str = ""

    # --- Advisory Engine ---
    ADVISORY_WINDOW_MINUTES: int = 60

    # --- Data Retention ---
    DATA_RETENTION_SENSOR_DAYS: int = 30
    DATA_RETENTION_CONTROL_DAYS: int = 90

    # --- Image Storage ---
    IMAGE_STORAGE_PATH: str = "./images"

    # --- API Keys ---
    API_KEYS: str = ""

    # --- Logging ---
    LOG_LEVEL: str = "INFO"

    # --- API ---
    API_V1_PREFIX: str = "/api/v1"
    PROJECT_NAME: str = "FarmEye Guard API"
    VERSION: str = "v1.0.0"


settings = Settings()
