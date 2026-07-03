/**
 * 防治建议服务。
 *
 * 提供综合防治建议的统一访问入口。
 *
 * 缓存键：`CACHE_KEY_PREFIX_ADVISORY + (deviceId ?? 'all') + '_' + (windowMinutes ?? 'all')`
 *  - 当 `deviceId` 与 `windowMinutes` 均为 `undefined` 时，键为 `... + 'all_all'`
 *  - **不**包含 `start` / `end`（与 `windowMinutes` 表达的时间窗口语义重叠）
 *
 * 缓存 TTL：`CACHE_TTL_ADVISORY_MS`（30s）
 *
 * 错误处理：
 * - 业务失败抛 `new Error(resp.message)`
 */

import { Advisory, ApiResponse } from '../common/models';
import { CacheManager } from '../common/CacheManager';
import { CACHE_KEY_PREFIX_ADVISORY, CACHE_TTL_ADVISORY_MS } from '../common/constants';
import { get as httpGet } from './HttpClient';

/**
 * 获取综合防治建议。
 *
 * - 缓存命中直接返回
 * - 缓存未命中时 `GET /advisory`，query 包含 `device_id?` / `start?` / `end?` / `window_minutes?`
 * - 字段 `undefined` 由 `HttpClient.get` 的 `buildQueryString` 自动跳过
 *
 * @param deviceId 可选设备 ID
 * @param start 可选开始时间
 * @param end 可选结束时间
 * @param windowMinutes 可选时间窗口（分钟）
 * @returns `Advisory` 响应（含 `latest_detection` / `current_env` / `env_disease_linkage` / `advisory`）
 * @throws 网络/业务异常
 */
async function getAdvisory(
  deviceId?: string,
  start?: string,
  end?: string,
  windowMinutes?: number
): Promise<Advisory> {
  const key: string = CACHE_KEY_PREFIX_ADVISORY + (deviceId ?? 'all') + '_' + (windowMinutes ?? 'all');

  const cached = CacheManager.get<Advisory>(key);
  if (cached !== null) {
    return cached;
  }

  const params: Record<string, string | number | undefined> = {};
  params['device_id'] = deviceId;
  params['start'] = start;
  params['end'] = end;
  params['window_minutes'] = windowMinutes;

  const resp: ApiResponse<Advisory> = await httpGet<Advisory>('/advisory', params);

  if (resp.code !== 0 || resp.data === null) {
    throw new Error(resp.message || 'Advisory error');
  }

  CacheManager.set(key, resp.data, CACHE_TTL_ADVISORY_MS);
  return resp.data;
}

export interface AdvisoryServiceType {
  getAdvisory: (deviceId?: string, start?: string, end?: string, windowMinutes?: number) => Promise<Advisory>;
}

export const AdvisoryService: AdvisoryServiceType = {
  getAdvisory: getAdvisory
};
