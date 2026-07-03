/**
 * 全局常量定义。
 *
 * 模块加载时一次性求值，敏感值（API_KEY）硬编码于开发调试阶段。
 * 所有 Service / Page / Component 通过相对路径
 * `import { ... } from '../common/constants'` 引用。
 */

// ============================
// HTTP 配置
// ============================

/** 后端基础 URL（不含 `/api/v1`，由 HttpClient 拼接）。 */
export const API_BASE_URL: string = 'http://<VPS_IP>:8000';

/** 接口路径前缀（HttpClient 拼接用）。 */
export const API_PATH_PREFIX: string = '/api/v1';

/** 测试 API Key。 */
export const API_KEY: string = 'farmeye_dev_key_001';

/** 业务鉴权请求头字段名。 */
export const HEADER_API_KEY: string = 'X-Api-Key';

/** HTTP 请求默认超时（10s）。 */
export const DEFAULT_TIMEOUT_MS: number = 10000;

/** 文件上传超时（60s）。 */
export const UPLOAD_TIMEOUT_MS: number = 60000;

// ============================
// 轮询间隔
// ============================

/** 首页传感器轮询间隔（10s）。 */
export const POLL_INTERVAL_INDEX_SENSOR_MS: number = 10000;

/** 首页告警轮询间隔（10s）。 */
export const POLL_INTERVAL_INDEX_ALARM_MS: number = 10000;

/** 仪表盘轮询间隔（10s）。 */
export const POLL_INTERVAL_DASHBOARD_MS: number = 10000;

/** 建议页轮询间隔（10s）。 */
export const POLL_INTERVAL_ADVISORY_MS: number = 10000;

/** 控制命令确认轮询间隔（1s）。 */
export const CONTROL_POLL_INTERVAL_MS: number = 1000;

/** 控制命令确认最大轮询次数。 */
export const CONTROL_POLL_MAX_TIMES: number = 5;

// ============================
// 缓存 TTL
// ============================

/** 通用缓存默认 TTL（30s）。 */
export const CACHE_DEFAULT_TTL_MS: number = 30000;

/** 传感器数据 TTL（30s）。 */
export const CACHE_TTL_SENSOR_MS: number = 30000;

/** 设备列表 TTL（60s）。 */
export const CACHE_TTL_DEVICE_MS: number = 60000;

/** 病虫害数据 TTL（60s）。 */
export const CACHE_TTL_DISEASE_MS: number = 60000;

/** 建议数据 TTL（30s）。 */
export const CACHE_TTL_ADVISORY_MS: number = 30000;

// ============================
// 缓存键前缀
// ============================

/** 单设备最新快照前缀。 */
export const CACHE_KEY_PREFIX_SENSOR_LATEST: string = 'sensor_latest_';

/** 全设备最新快照键。 */
export const CACHE_KEY_PREFIX_SENSOR_ALL_LATEST: string = 'sensor_all_latest';

/** 传感器历史数据前缀。 */
export const CACHE_KEY_PREFIX_SENSOR_HISTORY: string = 'sensor_history_';

/** 传感器日聚合前缀。 */
export const CACHE_KEY_PREFIX_SENSOR_DAILY: string = 'sensor_daily_';

/** 设备列表前缀。 */
export const CACHE_KEY_PREFIX_DEVICE_LIST: string = 'device_list_';

/** 病虫害列表前缀。 */
export const CACHE_KEY_PREFIX_DISEASE_LIST: string = 'disease_list_';

/** 病虫害统计键。 */
export const CACHE_KEY_PREFIX_DISEASE_STATS: string = 'disease_stats';

/** 热力图键。 */
export const CACHE_KEY_PREFIX_DISEASE_HEATMAP: string = 'disease_heatmap';

/** 防治建议前缀。 */
export const CACHE_KEY_PREFIX_ADVISORY: string = 'advisory_';

/** 控制日志前缀。 */
export const CACHE_KEY_PREFIX_COMMAND_LOGS: string = 'command_logs_';

// ============================
// 命令字符串
// ============================

/** 开 LED。 */
export const CMD_LED_ON: string = 'led ON';
/** 关 LED。 */
export const CMD_LED_OFF: string = 'led OFF';
/** 开蜂鸣器。 */
export const CMD_BEEP_ON: string = 'beep ON';
/** 关蜂鸣器。 */
export const CMD_BEEP_OFF: string = 'beep OFF';
/** 开喷淋。 */
export const CMD_SPRAY_ON: string = 'spray ON';
/** 关喷淋。 */
export const CMD_SPRAY_OFF: string = 'spray OFF';
/** 开灌溉。 */
export const CMD_IRRIG_ON: string = 'irrig ON';
/** 关灌溉。 */
export const CMD_IRRIG_OFF: string = 'irrig OFF';

/** 命令来源：鸿蒙端手动。 */
export const COMMAND_SOURCE_MANUAL_APP: string = 'manual_app';
/** 命令来源：上位机手动。 */
export const COMMAND_SOURCE_MANUAL_PC: string = 'manual_pc';
/** 命令来源：自动控制。 */
export const COMMAND_SOURCE_AUTO: string = 'auto';

/** 命令已下发状态字符串。 */
export const COMMAND_STATUS_SENT: string = 'sent';
/** 设备执行成功的 result_code。 */
export const COMMAND_STATUS_SUCCESS: number = 0;

// ============================
// 业务错误码（联合类型 ErrorCode）
// ============================

/** 业务错误码联合类型。 */
export type ErrorCode = 0 | 1001 | 1002 | 1003 | 1004 | 1005 | 2001 | 3001 | 5000;

export const ERR_CODE_SUCCESS: ErrorCode = 0;
export const ERR_CODE_INVALID_PARAM: ErrorCode = 1001;
export const ERR_CODE_NOT_FOUND: ErrorCode = 1002;
export const ERR_CODE_DEVICE_OFFLINE: ErrorCode = 1003;
export const ERR_CODE_INVALID_API_KEY: ErrorCode = 1004;
export const ERR_CODE_RATE_LIMIT: ErrorCode = 1005;
export const ERR_CODE_DB_ERROR: ErrorCode = 2001;
export const ERR_CODE_IOTDA_ERROR: ErrorCode = 3001;
export const ERR_CODE_INTERNAL: ErrorCode = 5000;

// ============================
// 报警位掩码
// ============================

/** 高温报警位。 */
export const ALARM_FLAG_HIGH_TEMP: number = 0x01;
/** 低温报警位。 */
export const ALARM_FLAG_LOW_TEMP: number = 0x02;
/** 高湿报警位。 */
export const ALARM_FLAG_HIGH_HUMIDITY: number = 0x04;
/** 低湿报警位。 */
export const ALARM_FLAG_LOW_HUMIDITY: number = 0x08;
/** 低光照报警位。 */
export const ALARM_FLAG_LOW_LIGHT: number = 0x10;
/** 高 CO2 报警位。 */
export const ALARM_FLAG_HIGH_CO2: number = 0x20;
/** 低氮报警位。 */
export const ALARM_FLAG_LOW_NITROGEN: number = 0x40;
/** 低磷报警位。 */
export const ALARM_FLAG_LOW_PHOSPHORUS: number = 0x80;

// ============================
// 重试相关
// ============================

/** 触发重试的 HTTP 状态码。 */
export const RETRY_STATUS_CODES: number[] = [408, 429, 502, 503, 504];

/** 重试基础延迟（1s）。 */
export const RETRY_BASE_DELAY_MS: number = 1000;

/** 重试最大延迟（10s）。 */
export const RETRY_MAX_DELAY_MS: number = 10000;

/** GET 最大重试次数。 */
export const RETRY_MAX_RETRIES: number = 3;
