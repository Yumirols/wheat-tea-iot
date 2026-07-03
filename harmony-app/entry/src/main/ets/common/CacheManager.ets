/**
 * 通用内存缓存管理器。
 *
 * 提供基于 TTL 自动失效的泛型键值缓存。模块级单例（`store`），
 * 由所有 Service 共享以支持"网络失败时返回最近一次成功数据"的能力。
 *
 * 时间基准采用 `utils.nowMs()`（即 `Date.now()`），过期判定为
 * `nowMs() - entry.timestamp > entry.ttl`。
 */

import { CacheEntry } from './models';
import { CACHE_DEFAULT_TTL_MS } from './constants';
import { nowMs } from './utils';

const store: Map<string, CacheEntry<Object>> = new Map();

export interface CacheManagerType {
  set: <T>(key: string, data: T, ttl?: number) => void;
  get: <T>(key: string) => T | null;
  invalidate: (key: string) => void;
  clear: () => void;
}

/**
 * 写入缓存条目。
 * @param key 缓存键
 * @param data 业务数据
 * @param ttl 可选 TTL（毫秒），默认 `CACHE_DEFAULT_TTL_MS`
 */
function set<T>(key: string, data: T, ttl?: number): void {
  const entry: CacheEntry<T> = {
    data: data,
    timestamp: nowMs(),
    ttl: ttl ?? CACHE_DEFAULT_TTL_MS
  };
  store.set(key, entry as Object as CacheEntry<Object>);
}

/**
 * 读取缓存条目，过期或不存在时返回 `null`。
 * @param key 缓存键
 */
function get<T>(key: string): T | null {
  const entry = store.get(key) as Object as CacheEntry<T> | undefined;
  if (entry === undefined) {
    return null;
  }
  if (nowMs() - entry.timestamp > entry.ttl) {
    store.delete(key);
    return null;
  }
  return entry.data;
}

/** 删除指定键。 */
function invalidate(key: string): void {
  store.delete(key);
}

/** 清空所有键。 */
function clear(): void {
  store.clear();
}

export const CacheManager: CacheManagerType = {
  set: set,
  get: get,
  invalidate: invalidate,
  clear: clear
};
