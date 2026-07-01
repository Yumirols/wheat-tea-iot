"""
FarmEye Guard v1.0 — 联动分析决策引擎

提供环境-病虫害联动分析（evaluate_linkage）、防治建议生成（generate_advisory）
和完整的防治建议查询（get_advisory）三个核心业务函数。

设计参考：docs/1_system_architecture.md §2.4 决策规则矩阵
"""
import logging
from datetime import datetime, timedelta, timezone
from typing import Any, Optional

from sqlalchemy.orm import Session

from app.config import settings
from app.models.disease import DiseaseRecord
from app.models.sensor import SensorSnapshot

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# 病虫害配置
# ---------------------------------------------------------------------------
DISEASE_CONFIG: dict[str, dict[str, Any]] = {
    "rust": {
        "name_cn": "锈病",
        "crop_cn": "小麦",
        "sev1_action": "manual_inspect",
        "sev1_desc": "检测到轻度小麦锈病，建议加强巡检，检查叶片状态。",
        "sev2_action": "spray_fungicide",
        "sev2_chemical": "三唑酮类杀菌剂",
        "sev2_triggered_desc": (
            "检测到中度小麦锈病（severity_code=2），建议在48h内喷施三唑酮类杀菌剂。"
            "当前温湿度条件适宜锈病扩散，请加强监测频率。"
        ),
        "sev2_not_triggered_desc": (
            "检测到中度小麦锈病（severity_code=2），建议持续监测。"
            "当前环境条件暂未达到锈病扩散触发阈值，但仍需保持警惕。"
        ),
        "sev3_action": "spray_fungicide",
        "sev3_desc": "检测到重度小麦锈病，请立即喷施三唑酮类杀菌剂并隔离病区。",
        "linkage_conditions": [
            {
                "name": "湿度偏高（> 85%）",
                "check": lambda t, h: h is not None and h > 85,
                "msg_match": "湿度 {h}% 超过锈病扩散阈值 85%",
            },
            {
                "name": "温度处于锈病适宜范围（15-25℃）",
                "check": lambda t, h: t is not None and 15 <= t <= 25,
                "msg_match": "温度 {t}℃ 处于锈病适宜范围 15-25℃",
            },
        ],
    },
    "powdery_mildew": {
        "name_cn": "白粉病",
        "crop_cn": "小麦",
        "sev1_action": "manual_inspect",
        "sev1_desc": "检测到轻度小麦白粉病，建议加强通风，降低湿度。",
        "sev2_action": "spray_fungicide",
        "sev2_chemical": "嘧菌酯",
        "sev2_triggered_desc": (
            "检测到中度小麦白粉病（severity_code=2），建议喷施嘧菌酯。"
            "当前湿度条件适宜白粉病发展，请加强监测。"
        ),
        "sev2_not_triggered_desc": (
            "检测到中度小麦白粉病（severity_code=2），建议持续监测。"
            "当前环境湿度暂未达到白粉病快速扩散条件。"
        ),
        "sev3_action": "spray_fungicide",
        "sev3_desc": "检测到重度小麦白粉病，请立即喷施杀菌剂并隔离病区。",
        "linkage_conditions": [
            {
                "name": "湿度处于白粉病适宜范围（50%-80%）",
                "check": lambda t, h: h is not None and 50 <= h <= 80,
                "msg_match": "湿度 {h}% 处于白粉病适宜范围 50%-80%",
            },
        ],
    },
    "anthracnose": {
        "name_cn": "茶炭疽病",
        "crop_cn": "茶叶",
        "sev1_action": "manual_inspect",
        "sev1_desc": "检测到轻度茶炭疽病，建议检查茶园湿度，加强巡查。",
        "sev2_action": "spray_fungicide",
        "sev2_chemical": "苯醚甲环唑",
        "sev2_triggered_desc": (
            "检测到中度茶炭疽病（severity_code=2），建议喷施苯醚甲环唑。"
            "当前温湿度条件适宜茶炭疽病发展，请加强监测频率。"
        ),
        "sev2_not_triggered_desc": (
            "检测到中度茶炭疽病（severity_code=2），建议持续监测。"
            "当前环境条件暂未达到茶炭疽病扩散触发阈值。"
        ),
        "sev3_action": "spray_fungicide",
        "sev3_desc": "检测到重度茶炭疽病，请立即喷施杀菌剂并隔离病区。",
        "linkage_conditions": [
            {
                "name": "湿度偏高（> 80%）",
                "check": lambda t, h: h is not None and h > 80,
                "msg_match": "湿度 {h}% 超过茶炭疽病扩散阈值 80%",
            },
            {
                "name": "温度处于茶炭疽病适宜范围（20-30℃）",
                "check": lambda t, h: t is not None and 20 <= t <= 30,
                "msg_match": "温度 {t}℃ 处于茶炭疽病适宜范围 20-30℃",
            },
        ],
    },
    "leafhopper": {
        "name_cn": "茶小绿叶蝉",
        "crop_cn": "茶叶",
        "sev1_action": "manual_inspect",
        "sev1_desc": "检测到茶小绿叶蝉（轻度），建议监控虫口密度，加强巡查。",
        "sev2_action": "spray_insecticide",
        "sev2_chemical": "吡虫啉",
        "sev2_triggered_desc": (
            "检测到中度茶小绿叶蝉危害（severity_code=2），建议喷施吡虫啉。"
            "当前温度条件适宜茶小绿叶蝉繁殖，请加强监测频率。"
        ),
        "sev2_not_triggered_desc": (
            "检测到中度茶小绿叶蝉危害（severity_code=2），建议持续监测。"
            "当前温度暂未达到茶小绿叶蝉高活跃度触发阈值。"
        ),
        "sev3_action": "spray_insecticide",
        "sev3_desc": "检测到重度茶小绿叶蝉危害，请立即喷施杀虫剂。",
        "linkage_conditions": [
            {
                "name": "温度处于茶小绿叶蝉适宜范围（20-30℃）",
                "check": lambda t, h: t is not None and 20 <= t <= 30,
                "msg_match": "温度 {t}℃ 处于茶小绿叶蝉适宜范围 20-30℃",
            },
        ],
    },
}


def get_advisory(
    db: Session,
    device_id: Optional[str] = None,
    start: Optional[datetime] = None,
    end: Optional[datetime] = None,
    window_minutes: Optional[int] = None,
) -> dict[str, Any]:
    """
    根据时间窗口内的 AI 识别结果和环境数据，返回防治建议。

    参数说明：
        db: 数据库会话
        device_id: 设备 ID（可选）
        start: 起始时间（可选，与 end 配对使用）
        end: 结束时间（可选，与 start 配对使用）
        window_minutes: 窗口分钟数（默认 settings.ADVISORY_WINDOW_MINUTES=60）

    返回字典包含：
        latest_detection (Optional[dict]): 最新检测信息
        current_env (Optional[dict]): 当前环境信息
        env_disease_linkage (Optional[dict]): 联动分析结果
        advisory (Optional[dict]): 防治建议

    时间窗口内无检测记录时所有字段均为 None。
    """
    now = datetime.now(timezone.utc).replace(tzinfo=None)

    # 1. 时间窗口计算
    if start and end:
        query_start = start
        query_end = end
    else:
        window = window_minutes or settings.ADVISORY_WINDOW_MINUTES
        query_end = now
        query_start = query_end - timedelta(minutes=window)

    result: dict[str, Any] = {
        "latest_detection": None,
        "current_env": None,
        "env_disease_linkage": None,
        "advisory": None,
    }

    # 2. 查询 disease_records（支持 device_id 筛选，取最新 1 条）
    detection_query = db.query(DiseaseRecord).filter(
        DiseaseRecord.timestamp >= query_start,
        DiseaseRecord.timestamp <= query_end,
    )
    if device_id:
        detection_query = detection_query.filter(
            DiseaseRecord.device_id == device_id
        )

    latest_detection: Optional[DiseaseRecord] = (
        detection_query.order_by(DiseaseRecord.timestamp.desc()).first()
    )

    if not latest_detection:
        return result

    result["latest_detection"] = {
        "crop_type": latest_detection.crop_type,
        "disease_type": latest_detection.disease_type,
        "severity": latest_detection.severity,
        "severity_code": latest_detection.severity_code,
        "confidence": (
            float(latest_detection.confidence)
            if latest_detection.confidence is not None
            else None
        ),
        "timestamp": latest_detection.timestamp,
    }

    # 3. 查询 sensor_snapshot（同一设备，同一时间窗口，取最新 1 条）
    env_query = db.query(SensorSnapshot).filter(
        SensorSnapshot.timestamp >= query_start,
        SensorSnapshot.timestamp <= query_end,
    )
    if device_id:
        env_query = env_query.filter(SensorSnapshot.device_id == device_id)

    current_env: Optional[SensorSnapshot] = (
        env_query.order_by(SensorSnapshot.timestamp.desc()).first()
    )

    if current_env:
        result["current_env"] = {
            "temperature": (
                float(current_env.temperature)
                if current_env.temperature is not None
                else None
            ),
            "humidity": (
                float(current_env.humidity)
                if current_env.humidity is not None
                else None
            ),
            "light": current_env.light,
            "co2": current_env.co2,
        }

    # 4. 环境-病虫害联动分析
    linkage: Optional[dict[str, Any]] = None
    if current_env:
        linkage = evaluate_linkage(latest_detection, current_env)
        result["env_disease_linkage"] = linkage

    # 5. 生成防治建议
    advisory = generate_advisory(latest_detection, linkage)
    result["advisory"] = advisory

    # 将联动分析结果持久化写入 disease_records
    if linkage:
        latest_detection.linkage_risk_level = linkage["risk_level"]
        latest_detection.linkage_detail = str(linkage)
        db.commit()

    return result


def evaluate_linkage(
    detection: DiseaseRecord,
    env_data: SensorSnapshot,
) -> dict[str, Any]:
    """
    环境-病虫害联动分析。

    根据病虫害类型和相关环境因子判断风险等级。
    返回字典包含 risk_level, matched_conditions, recommendation。
    """
    disease_type = detection.disease_type

    # 获取病虫害配置，未知类型使用默认空规则
    config = DISEASE_CONFIG.get(disease_type)
    if not config:
        return {
            "risk_level": "low",
            "matched_conditions": [],
            "recommendation": f"未知病虫害类型（{disease_type}），无法进行联动分析，建议保持常规监测。",
        }

    temp = float(env_data.temperature) if env_data.temperature is not None else None
    hum = float(env_data.humidity) if env_data.humidity is not None else None

    # 逐一检查环境条件
    matched_conditions: list[str] = []
    for condition in config["linkage_conditions"]:
        if condition["check"](temp, hum):
            matched_conditions.append(
                condition["msg_match"].format(
                    t=temp if temp is not None else 0,
                    h=hum if hum is not None else 0,
                )
            )

    # 根据匹配条件数量确定风险等级
    match_count = len(matched_conditions)
    if match_count >= 2:
        risk_level = "high"
    elif match_count == 1:
        risk_level = "medium"
    else:
        risk_level = "low"

    # 生成中文推荐建议
    recommendation = _build_recommendation(
        disease_type, config["name_cn"], risk_level, matched_conditions
    )

    return {
        "risk_level": risk_level,
        "matched_conditions": matched_conditions,
        "recommendation": recommendation,
    }


def _build_recommendation(
    disease_type: str,
    disease_cn: str,
    risk_level: str,
    matched_conditions: list[str],
) -> str:
    """根据风险等级和匹配条件生成中文推荐建议。"""
    if risk_level == "low":
        return (
            f"当前环境条件对{disease_cn}扩散风险较低，"
            f"建议保持常规监测（10min/次）。"
        )
    elif risk_level == "medium":
        return (
            f"当前环境存在有利于{disease_cn}扩散的条件"
            f"（{'; '.join(matched_conditions)}），"
            f"建议加强监测频率至5min/次。"
        )
    else:  # high
        return (
            f"当前环境条件非常有利于{disease_cn}扩散"
            f"（{'; '.join(matched_conditions)}），"
            f"建议立即采取防治措施，监测频率提升至2min/次。"
        )


def generate_advisory(
    detection: DiseaseRecord,
    linkage: Optional[dict[str, Any]] = None,
) -> dict[str, Any]:
    """
    基于决策规则矩阵生成防治建议。

    规则矩阵（docs/1_system_architecture.md §2.4 决策规则矩阵）：
      - severity_code=1: manual_inspect，给出监测建议
      - severity_code=2: 检查环境条件是否触发，触发则给出具体药剂建议
      - severity_code=3: auto_action_triggered=True, auto_action="spray ON"
    """
    disease_type = detection.disease_type
    severity_code = detection.severity_code

    # 获取病虫害配置
    config = DISEASE_CONFIG.get(disease_type)

    # 未知病虫害类型
    if not config:
        return {
            "action": "manual_inspect",
            "description": f"检测到未知病虫害类型（{disease_type}），请人工确认并制定防治方案。",
            "auto_action_triggered": False,
            "auto_action": None,
        }

    # 判断环境触发条件
    matched_conditions = linkage.get("matched_conditions", []) if linkage else []
    env_triggered = len(matched_conditions) > 0

    # ----- 决策规则矩阵 -----
    if severity_code == 1:
        # 轻度：一律 manual_inspect
        action = config["sev1_action"]
        description = config["sev1_desc"]
        auto_action_triggered = False
        auto_action = None

    elif severity_code == 2:
        # 中度：环境触发则具体药剂，否则 manual_inspect
        if env_triggered:
            action = config["sev2_action"]
            description = config["sev2_triggered_desc"]
        else:
            action = "manual_inspect"
            description = config["sev2_not_triggered_desc"]
        auto_action_triggered = False
        auto_action = None

    elif severity_code == 3:
        # 重度：自动动作触发 spray ON
        action = config["sev3_action"]
        description = config["sev3_desc"]
        auto_action_triggered = True
        auto_action = "spray ON"

    else:
        # 未知 severity_code
        action = "manual_inspect"
        description = (
            f"检测到{config['crop_cn']}{config['name_cn']}"
            f"（severity_code={severity_code}），请人工确认并处理。"
        )
        auto_action_triggered = False
        auto_action = None

    return {
        "action": action,
        "description": description,
        "auto_action_triggered": auto_action_triggered,
        "auto_action": auto_action,
    }
