/**
 * 传感器数据服务。
 *
 * 提供四类数据访问：
 * - `getLatest(deviceId)`：单设备最新快照（强制 `deviceId`，缓存）
 * - `getAllLatest()`：所有设备最新快照数组（固定键缓存）
 * - `getHistory(deviceId, start?, end?, page?, pageSize?)`：历史分页（不缓存）
 * - `getDaily(deviceId, start, end, page?, pageSize?)`：日聚合分页（不缓存）
 *
 * 缓存键：
 * - 单设备：`CACHE_KEY_PREFIX_SENSOR_LATEST + deviceId`
 * - 全量：`CACHE_KEY_PREFIX_SENSOR_ALL_LATEST`（固定）
 * 缓存 TTL：`CACHE_TTL_SENSOR_MS`
 *
 * 参数映射：
 * - `pageSize` → 查询参数 `page_size`（snake_case 转换）
 *
 * 错误处理：
 * - `getLatest` 在 `data` 为数组时抛 `Error('Expected single sensor snapshot')`
 * - 业务失败抛 `new Error(resp.message)`
 */

import { SensorSnapshot, SensorHistory, DailyAggregation, PaginatedData, ApiResponse } from '../common/models';
import { CacheManager } from '../common/CacheManager';
import {
  CACHE_KEY_PREFIX_SENSOR_LATEST,
  CACHE_KEY_PREFIX_SENSOR_ALL_LATEST,
  CACHE_TTL_SENSOR_MS
} from '../common/constants';
import { get as httpGet } from './HttpClient';

/**
 * 单设备最新传感器快照。
 *
 * - 缓存命中直接返回
 * - 缓存未命中时调用 `/sensor/latest?device_id=xxx`
 * - 当后端返回数组（如空 `deviceId` 命中后端"无过滤"分支）时抛 `Error('Expected single sensor snapshot')`
 *
 * @param deviceId 设备 ID（必填；空字符串视作"无设备过滤"，后端将返回数组形态）
 * @returns 单条 `SensorSnapshot`
 * @throws 网络/业务异常；后端返回数组时抛 `Error('Expected single sensor snapshot')`
 */
async function getLatest(deviceId: string): Promise<SensorSnapshot> {
  const key: string = CACHE_KEY_PREFIX_SENSOR_LATEST + deviceId;

  const cached = CacheManager.get<SensorSnapshot>(key);
  if (cached !== null) {
    return cached;
  }

  const params: Record<string, string | number | undefined> = {};
  params['device_id'] = deviceId;

  const resp: ApiResponse<SensorSnapshot | SensorSnapshot[]> =
    await httpGet<SensorSnapshot | SensorSnapshot[]>('/sensor/latest', params);

  if (resp.code !== 0 || resp.data === null) {
    throw new Error(resp.message || 'Sensor latest error');
  }

  // 后端"传 device_id"语义返回单条；若返回数组则视为契约违反
  if (Array.isArray(resp.data)) {
    throw new Error('Expected single sensor snapshot');
  }

  CacheManager.set(key, resp.data, CACHE_TTL_SENSOR_MS);
  return resp.data;
}

/**
 * 全设备最新传感器快照。
 *
 * - 缓存命中直接返回
 * - 缓存未命中时调用 `/sensor/latest`（不传 `device_id`）
 * - 缓存键固定为 `CACHE_KEY_PREFIX_SENSOR_ALL_LATEST`
 *
 * @returns 所有设备的 `SensorSnapshot[]`
 * @throws 网络/业务异常
 */
async function getAllLatest(): Promise<SensorSnapshot[]> {
  const key: string = CACHE_KEY_PREFIX_SENSOR_ALL_LATEST;

  const cached = CacheManager.get<SensorSnapshot[]>(key);
  if (cached !== null) {
    return cached;
  }

  const params: Record<string, string | number | undefined> = {};

  const resp: ApiResponse<SensorSnapshot[]> =
    await httpGet<SensorSnapshot[]>('/sensor/latest', params);

  if (resp.code !== 0 || resp.data === null) {
    throw new Error(resp.message || 'Sensor all latest error');
  }

  CacheManager.set(key, resp.data, CACHE_TTL_SENSOR_MS);
  return resp.data;
}

/**
 * 传感器历史分页。
 *
 * - **不**缓存（分页+时间范围组合空间大）
 * - `pageSize` 映射为查询参数 `page_size`
 *
 * @param deviceId 设备 ID
 * @param start 可选开始时间（ISO 字符串）
 * @param end 可选结束时间（ISO 字符串）
 * @param page 可选页码
 * @param pageSize 可选每页条数
 * @returns 分页数据
 * @throws 网络/业务异常
 */
async function getHistory(
  deviceId: string,
  start?: string,
  end?: string,
  page?: number,
  pageSize?: number
): Promise<PaginatedData<SensorHistory>> {
  const queryParams: Record<string, string | number | undefined> = {};
  queryParams['device_id'] = deviceId;
  queryParams['start'] = start;
  queryParams['end'] = end;
  queryParams['page'] = page;
  queryParams['page_size'] = pageSize;

  const resp: ApiResponse<PaginatedData<SensorHistory>> =
    await httpGet<PaginatedData<SensorHistory>>('/sensor/history', queryParams);

  if (resp.code !== 0 || resp.data === null) {
    throw new Error(resp.message || 'Sensor history error');
  }

  return resp.data;
}

/**
 * 传感器日聚合分页。
 *
 * - **不**缓存（分页+时间范围组合空间大）
 * - `pageSize` 映射为查询参数 `page_size`
 *
 * @param deviceId 设备 ID
 * @param start 开始时间（必填，ISO 字符串）
 * @param end 结束时间（必填，ISO 字符串）
 * @param page 可选页码
 * @param pageSize 可选每页条数
 * @returns 分页数据
 * @throws 网络/业务异常
 */
async function getDaily(
  deviceId: string,
  start: string,
  end: string,
  page?: number,
  pageSize?: number
): Promise<PaginatedData<DailyAggregation>> {
  const queryParams: Record<string, string | number | undefined> = {};
  queryParams['device_id'] = deviceId;
  queryParams['start'] = start;
  queryParams['end'] = end;
  queryParams['page'] = page;
  queryParams['page_size'] = pageSize;

  const resp: ApiResponse<PaginatedData<DailyAggregation>> =
    await httpGet<PaginatedData<DailyAggregation>>('/sensor/daily', queryParams);

  if (resp.code !== 0 || resp.data === null) {
    throw new Error(resp.message || 'Sensor daily error');
  }

  return resp.data;
}

export interface SensorServiceType {
  getLatest: (deviceId: string) => Promise<SensorSnapshot>;
  getAllLatest: () => Promise<SensorSnapshot[]>;
  getHistory: (deviceId: string, start?: string, end?: string, page?: number, pageSize?: number) => Promise<PaginatedData<SensorHistory>>;
  getDaily: (deviceId: string, start: string, end: string, page?: number, pageSize?: number) => Promise<PaginatedData<DailyAggregation>>;
}

export const SensorService: SensorServiceType = {
  getLatest: getLatest,
  getAllLatest: getAllLatest,
  getHistory: getHistory,
  getDaily: getDaily
};
