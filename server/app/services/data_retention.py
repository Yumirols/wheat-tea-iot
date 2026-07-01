"""
FarmEye Guard v1.0 — 数据保留定时任务

提供过期数据清理函数，定时删除超期 sensor_snapshot 明细和 control_logs 数据。

设计决策：
  - 定义为普通同步函数（非 async def），内部使用同步 SQLAlchemy 调用（SessionLocal）
  - 在 APScheduler 中配置时使用 ThreadPoolExecutor，避免阻塞事件循环
  - 定时注册在 main.py 的 startup 事件中通过 APScheduler 注册（当前仅实现函数逻辑）

设计参考：docs/2_vps-deployment.md §2.4
"""
import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy import text

from app.config import settings
from app.db.session import SessionLocal

logger = logging.getLogger(__name__)


def cleanup_expired_data() -> None:
    """
    清理过期数据。

    执行步骤：
    1. 聚合 DATA_RETENTION_SENSOR_DAYS（默认 30）天前的 sensor_snapshot
       数据到 sensor_daily_aggregation，使用 ON CONFLICT DO NOTHING
    2. 删除已聚合的 sensor_snapshot 原始明细
    3. 删除 DATA_RETENTION_CONTROL_DAYS（默认 90）天前的 control_logs 数据

    事务性：全部成功则 commit，异常则 rollback。
    """
    db = SessionLocal()
    try:
        now = datetime.now(timezone.utc).replace(tzinfo=None)

        sensor_retention_days = settings.DATA_RETENTION_SENSOR_DAYS
        control_retention_days = settings.DATA_RETENTION_CONTROL_DAYS

        # 步骤 1：聚合 sensor_snapshot 到 sensor_daily_aggregation
        cutoff_sensor = now - timedelta(days=sensor_retention_days)

        result_agg = db.execute(
            text(
                """
                INSERT INTO sensor_daily_aggregation (
                    device_id, agg_date,
                    avg_temperature, max_temperature, min_temperature,
                    avg_humidity, max_humidity, min_humidity,
                    avg_light, max_light, min_light,
                    avg_co2, max_co2, min_co2,
                    record_count
                )
                SELECT
                    device_id,
                    DATE(timestamp) AS agg_date,
                    AVG(temperature), MAX(temperature), MIN(temperature),
                    AVG(humidity), MAX(humidity), MIN(humidity),
                    AVG(light), MAX(light), MIN(light),
                    AVG(co2), MAX(co2), MIN(co2),
                    COUNT(*)
                FROM sensor_snapshot
                WHERE timestamp < :cutoff
                GROUP BY device_id, DATE(timestamp)
                ON CONFLICT (device_id, agg_date) DO NOTHING
                """
            ),
            {"cutoff": cutoff_sensor},
        )
        logger.info(
            "Data retention step 1: aggregated %d sensor rows (before %s)",
            result_agg.rowcount,
            cutoff_sensor,
        )

        # 步骤 2：删除已聚合的 sensor_snapshot 原始明细
        result_delete_sensor = db.execute(
            text(
                """
                DELETE FROM sensor_snapshot
                WHERE timestamp < :cutoff
                """
            ),
            {"cutoff": cutoff_sensor},
        )
        logger.info(
            "Data retention step 2: deleted %d sensor_snapshot rows (before %s)",
            result_delete_sensor.rowcount,
            cutoff_sensor,
        )

        # 步骤 3：删除过期 control_logs 数据
        cutoff_control = now - timedelta(days=control_retention_days)
        result_delete_control = db.execute(
            text(
                """
                DELETE FROM control_logs
                WHERE timestamp < :cutoff
                """
            ),
            {"cutoff": cutoff_control},
        )
        logger.info(
            "Data retention step 3: deleted %d control_log rows (before %s)",
            result_delete_control.rowcount,
            cutoff_control,
        )

        db.commit()
        logger.info(
            "Data retention cleanup completed: "
            "sensor before %s, control before %s",
            cutoff_sensor,
            cutoff_control,
        )

    except Exception as exc:
        db.rollback()
        logger.error(
            "Data retention cleanup failed: %s",
            str(exc),
            exc_info=True,
        )
        raise

    finally:
        db.close()
