/**
 * 设备服务。
 *
 * 负责 `/device/list` 的拉取、缓存与同步访问。
 * - `getDeviceList` 强制远程拉取（写入 `CacheManager` 与模块级 `cachedDevices`）
 * - `getCachedDevices` 同步返回模块级缓存（**不**触发远程请求）
 * - `refreshDevices` 与 `getDeviceList` 等价；为 `CommandService` 失败路径刷新缓存提供显式入口
 *
 * 缓存键格式：`CACHE_KEY_PREFIX_DEVICE_LIST + (deviceId ?? 'all')`
 * 缓存 TTL：`CACHE_TTL_DEVICE_MS`
 *
 * 错误处理：
 * - 网络层异常由 `HttpClient` 抛出，本服务透传
 * - 业务层失败（`code !== 0` 或 `data === null`）抛 `new Error(resp.message)`
 */

import { DeviceInfo, ApiResponse } from '../common/models';
import { CacheManager } from '../common/CacheManager';
import { CACHE_KEY_PREFIX_DEVICE_LIST, CACHE_TTL_DEVICE_MS } from '../common/constants';
import { nowMs } from '../common/utils';
import { get as httpGet } from './HttpClient';

/** 模块级设备缓存（最近一次"全量拉取"结果）。 */
let cachedDevices: DeviceInfo[] = [];

/** 最近一次全量拉取时间戳（毫秒），`0` 表示"从未获取"。 */
let lastFetchTime: number = 0;

/**
 * 生成缓存键。
 * @param deviceId 设备 ID（可选）
 * @returns 完整缓存键字符串
 */
function cacheKey(deviceId?: string): string {
  return CACHE_KEY_PREFIX_DEVICE_LIST + (deviceId ?? 'all');
}

/**
 * 强制远程拉取设备列表。
 *
 * - 始终发起远程请求（**不**读模块级缓存）
 * - 成功时写入 `CacheManager`（key 含 `deviceId` 维度）
 * - 当 `deviceId === undefined`（全量拉取）时，同时更新模块级 `cachedDevices` 与 `lastFetchTime`
 * - 单设备拉取（`deviceId` 提供时）**不**更新模块级 `cachedDevices`，避免单设备结果覆盖全量缓存
 *
 * @param deviceId 可选设备 ID 过滤
 * @returns 设备列表（解包后）
 * @throws 网络层异常（来自 `HttpClient`）或业务层异常（`new Error(resp.message)`）
 */
async function getDeviceList(deviceId?: string): Promise<DeviceInfo[]> {
  const queryParams: Record<string, string | number | undefined> = {};
  if (deviceId !== undefined) {
    queryParams['device_id'] = deviceId;
  }

  const resp: ApiResponse<DeviceInfo[]> = await httpGet<DeviceInfo[]>('/device/list', queryParams);

  if (resp.code !== 0 || resp.data === null) {
    throw new Error(resp.message || 'Device list error');
  }

  // 写入带 deviceId 维度的 CacheManager 缓存
  CacheManager.set(cacheKey(deviceId), resp.data, CACHE_TTL_DEVICE_MS);

  // 仅全量拉取时更新模块级缓存
  if (deviceId === undefined) {
    cachedDevices = resp.data;
    lastFetchTime = nowMs();
  }

  return resp.data;
}

/**
 * 同步返回模块级设备缓存。
 *
 * - **不**触发远程请求
 * - 若 `lastFetchTime === 0`（从未拉取）返回 `[]`
 * - 缓存超过 `CACHE_TTL_DEVICE_MS` 时仍返回当前缓存（**不主动失效**），
 *   调用方可自行决定是否 `refreshDevices` 主动刷新
 * - `deviceId` 提供时按 `device_id` 字段过滤；未提供时返回 `cachedDevices` 引用
 *
 * @param deviceId 可选设备 ID 过滤
 * @returns 设备列表（可能为空数组，不抛错）
 */
function getCachedDevices(deviceId?: string): DeviceInfo[] {
  if (deviceId !== undefined) {
    return cachedDevices.filter((d) => d.device_id === deviceId);
  }
  return cachedDevices;
}

/**
 * 主动刷新设备缓存。
 *
 * 与 `getDeviceList` 内部逻辑一致；为 `CommandService` 失败路径（设备离线）刷新缓存提供显式入口。
 *
 * @param deviceId 可选设备 ID 过滤
 * @returns 设备列表
 * @throws 同 `getDeviceList`
 */
async function refreshDevices(deviceId?: string): Promise<DeviceInfo[]> {
  return getDeviceList(deviceId);
}

export interface DeviceServiceType {
  getDeviceList: (deviceId?: string) => Promise<DeviceInfo[]>;
  getCachedDevices: (deviceId?: string) => DeviceInfo[];
  refreshDevices: (deviceId?: string) => Promise<DeviceInfo[]>;
}

export const DeviceService: DeviceServiceType = {
  getDeviceList: getDeviceList,
  getCachedDevices: getCachedDevices,
  refreshDevices: refreshDevices
};
