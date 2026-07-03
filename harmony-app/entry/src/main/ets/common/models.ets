/**
 * 业务数据模型与基础类型定义。
 *
 * 本文件仅包含 ArkTS `interface` / `type` 声明，编译期被擦除，
 * 不产生任何运行时副作用。所有 Service / Page / Component 通过相对路径
 * `import { ... } from '../common/models'` 引用。
 */

// ============================
// 业务实体（与后端 API 字段一一对应）
// ============================

/** `/device/list` 返回的设备实体。 */
export interface DeviceInfo {
  id: number;
  device_id: string;
  device_name: string;
  mac_addr: string;
  ip_addr: string;
  registered_at: string;
  last_seen: string;
  online: boolean;
  created_at: string;
}

/** `/sensor/latest` 单条快照实体。 */
export interface SensorSnapshot {
  id: number;
  device_id: string;
  mac_addr: string;
  timestamp: string;
  temperature: number;
  humidity: number;
  light: number;
  co2: number;
  soil_n: number;
  soil_p: number;
  soil_k: number;
  distance: number;
  rssi: number;
  ip_addr: string;
  alarm_flag: number;
  created_at: string;
}

/** `/sensor/history` 历史记录实体。 */
export interface SensorHistory {
  id: number;
  device_id: string;
  timestamp: string;
  temperature: number;
  humidity: number;
  light: number;
  co2: number;
  soil_n: number;
  soil_p: number;
  soil_k: number;
  distance: number;
  rssi: number;
  ip_addr: string;
  alarm_flag: number;
}

/** `/sensor/daily` 日聚合实体。 */
export interface DailyAggregation {
  id: number;
  device_id: string;
  agg_date: string;
  avg_temperature: number;
  max_temperature: number;
  min_temperature: number;
  avg_humidity: number;
  max_humidity: number;
  min_humidity: number;
  avg_light: number;
  max_light: number;
  min_light: number;
  avg_co2: number;
  max_co2: number;
  min_co2: number;
  record_count: number;
  created_at: string;
}

/** `/disease/list` 病虫害记录实体。 */
export interface DiseaseRecord {
  id: number;
  device_id: string;
  timestamp: string;
  crop_type: string;
  disease_type: string;
  confidence: number;
  severity: string;
  severity_code: number;
  linkage_risk_level: string;
  linkage_detail: string;
  image_path: string;
  action_taken: string;
  created_at: string;
}

/** `/disease/stats` 统计响应。 */
export interface DiseaseStats {
  total_detections: number;
  by_crop: Record<string, number>;
  by_severity: Record<string, number>;
  by_disease: Record<string, number>;
}

/** 热力图单点（`/disease/heatmap` 响应 `data.heatmap_points` 元素）。 */
export interface HeatmapPoint {
  device_id: string;
  disease_type: string;
  severity: string;
  timestamp: string;
  crop_type: string;
}

/** 热力图汇总（`/disease/heatmap` 响应 `data.summary`）。 */
export interface HeatmapSummary {
  active_disease_types: number;
  affected_devices: number;
  total_records: number;
}

/** `/disease/heatmap` 整体响应 `data`。 */
export interface HeatmapData {
  heatmap_points: HeatmapPoint[];
  summary: HeatmapSummary;
}

/** `/command/send` 请求体。 */
export interface CommandRequest {
  device_id: string;
  command: string;
  source?: string;
  operator?: string;
}

/** `/command/send` 成功响应 `data` 字段实体（参见 client-api-reference §2.5.1）。 */
export interface CommandResponse {
  command_id: string;
  device_id: string;
  command: string;
  status: string;
}

/** `/command/logs` 控制日志实体。 */
export interface CommandLog {
  id: number;
  device_id: string;
  command_id: string;
  timestamp: string;
  command: string;
  source: string;
  operator: string;
  result_code: number;
  result_msg: string;
}

/** `/advisory` 中最新检测子结构。 */
export interface AdvisoryDetection {
  crop_type: string;
  disease_type: string;
  severity: string;
  severity_code: number;
  confidence: number;
  timestamp: string;
}

/** `/advisory` 中环境子结构。 */
export interface AdvisoryEnv {
  temperature: number;
  humidity: number;
  light: number;
  co2: number;
}

/** `/advisory` 中环境-病虫害联动分析子结构。 */
export interface AdvisoryLinkage {
  risk_level: string;
  matched_conditions: string[];
  recommendation: string;
}

/** `/advisory` 中建议动作子结构。 */
export interface AdvisoryAction {
  action: string;
  description: string;
  auto_action_triggered: boolean;
  auto_action: string | null;
}

/** `/advisory` 整体响应 `data`。 */
export interface Advisory {
  latest_detection: AdvisoryDetection | null;
  current_env: AdvisoryEnv | null;
  env_disease_linkage: AdvisoryLinkage | null;
  advisory: AdvisoryAction | null;
}

/** `/image/upload` 上传结果。 */
export interface ImageUploadResult {
  image_id: string;
  image_path: string;
  file_size: number;
  uploaded_at: string;
}

// ============================
// 响应封装（api.ets 原始层 + 业务层）
// ============================

/** `api.request()` 原始响应封装（JSON 文本场景）。 */
export interface TextResult {
  statusCode: number;
  headers: Record<string, string>;
  rawBody: string;
}

/** `api.requestRaw()` 原始响应封装（二进制场景）。 */
export interface BinaryResult {
  statusCode: number;
  headers: Record<string, string>;
  rawBody: ArrayBuffer;
}

/** 通用 API 响应外层结构。 */
export interface ApiResponse<T> {
  code: number;
  message: string;
  data: T | null;
}

/** 分页元数据。 */
export interface Pagination {
  total: number;
  page: number;
  page_size: number;
}

/** 分页数据结构。 */
export interface PaginatedData<T> {
  pagination: Pagination;
  records: T[];
}

// ============================
// 基础设施
// ============================

/** 缓存条目（含数据快照时间与 TTL）。 */
export interface CacheEntry<T> {
  data: T;
  timestamp: number;
  ttl: number;
}

/** 重试策略配置。`timeoutMs` 字段为契约保留字段，当前重试循环不直接消费。 */
export interface RetryPolicyConfig {
  maxRetries: number;
  baseDelayMs: number;
  maxDelayMs: number;
  retryOn: number[];
  timeoutMs: number;
}

// ============================
// 行为类型
// ============================

/** 轮询回调签名：异步无参无返回。 */
export type PollingCallback = () => Promise<void>;

/** 页面连接状态联合类型。 */
export type ConnectivityStatus = 'loading' | 'online' | 'offline';
