/**
 * 病虫害服务。
 *
 * 提供三类数据访问：
 * - `getList(filters?)`：病虫害分页列表（多维筛选，**不**缓存）
 * - `getStats(start?, end?)`：统计汇总（按 `start + '_' + end` 缓存）
 * - `getHeatmap(start?, end?)`：热力图（**固定键**全局缓存）
 *
 * 缓存键：
 * - 统计：`CACHE_KEY_PREFIX_DISEASE_STATS + (start ?? 'all') + '_' + (end ?? 'all')`
 * - 热力图：`CACHE_KEY_PREFIX_DISEASE_HEATMAP`（全局共享）
 * 缓存 TTL：`CACHE_TTL_DISEASE_MS`
 *
 * 错误处理：
 * - 业务失败抛 `new Error(resp.message)`
 * - 列表查询字段 `undefined` 由 `HttpClient.get` 的 `buildQueryString` 自动跳过
 */

import { DiseaseRecord, DiseaseStats, HeatmapData, PaginatedData, ApiResponse } from '../common/models';
import { CacheManager } from '../common/CacheManager';
import {
  CACHE_KEY_PREFIX_DISEASE_STATS,
  CACHE_KEY_PREFIX_DISEASE_HEATMAP,
  CACHE_TTL_DISEASE_MS
} from '../common/constants';
import { get as httpGet } from './HttpClient';

/** 病虫害列表筛选条件（任一字段 `undefined` 即跳过该过滤）。 */
export interface DiseaseListFilters {
  device_id?: string;
  crop_type?: string;
  disease_type?: string;
  severity?: string;
  start?: string;
  end?: string;
  page?: number;
  page_size?: number;
}

/**
 * 病虫害分页列表。
 *
 * - **不**缓存（多维筛选+分页组合空间大）
 * - 筛选字段以 `undefined` 表示"不过滤该字段"
 *
 * @param filters 可选筛选条件
 * @returns 分页数据
 * @throws 网络/业务异常
 */
async function getList(filters?: DiseaseListFilters): Promise<PaginatedData<DiseaseRecord>> {
  const queryParams: Record<string, string | number | undefined> = {};
  if (filters !== undefined) {
    queryParams['device_id'] = filters.device_id;
    queryParams['crop_type'] = filters.crop_type;
    queryParams['disease_type'] = filters.disease_type;
    queryParams['severity'] = filters.severity;
    queryParams['start'] = filters.start;
    queryParams['end'] = filters.end;
    queryParams['page'] = filters.page;
    queryParams['page_size'] = filters.page_size;
  }

  const resp: ApiResponse<PaginatedData<DiseaseRecord>> =
    await httpGet<PaginatedData<DiseaseRecord>>('/disease/list', queryParams);

  if (resp.code !== 0 || resp.data === null) {
    throw new Error(resp.message || 'Disease list error');
  }

  return resp.data;
}

/**
 * 病虫害统计。
 *
 * - 缓存键：`CACHE_KEY_PREFIX_DISEASE_STATS + (start ?? 'all') + '_' + (end ?? 'all')`
 * - 当 `start` / `end` 均为 `undefined` 时，键为 `... + 'all_all'`
 *
 * @param start 可选开始时间
 * @param end 可选结束时间
 * @returns 统计响应
 * @throws 网络/业务异常
 */
async function getStats(start?: string, end?: string): Promise<DiseaseStats> {
  const key: string = CACHE_KEY_PREFIX_DISEASE_STATS + (start ?? 'all') + '_' + (end ?? 'all');

  const cached = CacheManager.get<DiseaseStats>(key);
  if (cached !== null) {
    return cached;
  }

  const resp: ApiResponse<DiseaseStats> = await httpGet<DiseaseStats>('/disease/stats', {
    start: start,
    end: end
  });

  if (resp.code !== 0 || resp.data === null) {
    throw new Error(resp.message || 'Disease stats error');
  }

  CacheManager.set(key, resp.data, CACHE_TTL_DISEASE_MS);
  return resp.data;
}

/**
 * 病虫害热力图数据。
 *
 * - 缓存键固定为 `CACHE_KEY_PREFIX_DISEASE_HEATMAP`（全局数据共享缓存）
 * - 时间范围仅影响请求，不影响缓存键
 *
 * @param start 可选开始时间
 * @param end 可选结束时间
 * @returns 热力图响应（含 `heatmap_points` 与 `summary`）
 * @throws 网络/业务异常
 */
async function getHeatmap(start?: string, end?: string): Promise<HeatmapData> {
  const key: string = CACHE_KEY_PREFIX_DISEASE_HEATMAP;

  const cached = CacheManager.get<HeatmapData>(key);
  if (cached !== null) {
    return cached;
  }

  const resp: ApiResponse<HeatmapData> = await httpGet<HeatmapData>('/disease/heatmap', {
    start: start,
    end: end
  });

  if (resp.code !== 0 || resp.data === null) {
    throw new Error(resp.message || 'Disease heatmap error');
  }

  CacheManager.set(key, resp.data, CACHE_TTL_DISEASE_MS);
  return resp.data;
}

export const DiseaseService = {
  getList: getList,
  getStats: getStats,
  getHeatmap: getHeatmap
};
