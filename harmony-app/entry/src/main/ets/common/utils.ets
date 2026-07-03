/**
 * 工具函数集合。
 *
 * 全部为无副作用的纯函数。涉及时间的统一走 `nowMs()` 以便测试替换。
 */

import {
  ALARM_FLAG_HIGH_TEMP,
  ALARM_FLAG_LOW_TEMP,
  ALARM_FLAG_HIGH_HUMIDITY,
  ALARM_FLAG_LOW_HUMIDITY,
  ALARM_FLAG_LOW_LIGHT,
  ALARM_FLAG_HIGH_CO2,
  ALARM_FLAG_LOW_NITROGEN,
  ALARM_FLAG_LOW_PHOSPHORUS
} from './constants';

/**
 * 将 ISO 时间字符串格式化为 `YYYY-MM-DD HH:mm:ss`。
 * 解析失败时原样返回入参。
 */
export function formatTimestamp(iso: string): string {
  const d: Date = new Date(iso);
  if (isNaN(d.getTime())) {
    return iso;
  }
  const pad = (n: number): string => (n < 10 ? '0' + n : '' + n);
  return (
    d.getFullYear() +
    '-' + pad(d.getMonth() + 1) +
    '-' + pad(d.getDate()) +
    ' ' + pad(d.getHours()) +
    ':' + pad(d.getMinutes()) +
    ':' + pad(d.getSeconds())
  );
}

/**
 * 按位与 `ALARM_FLAG_*` 掩码，解析激活的报警名数组。
 * @param flag 原始整型报警位掩码
 */
export function parseAlarmFlag(flag: number): string[] {
  const result: string[] = [];
  if ((flag & ALARM_FLAG_HIGH_TEMP) !== 0) {
    result.push('高温');
  }
  if ((flag & ALARM_FLAG_LOW_TEMP) !== 0) {
    result.push('低温');
  }
  if ((flag & ALARM_FLAG_HIGH_HUMIDITY) !== 0) {
    result.push('高湿');
  }
  if ((flag & ALARM_FLAG_LOW_HUMIDITY) !== 0) {
    result.push('低湿');
  }
  if ((flag & ALARM_FLAG_LOW_LIGHT) !== 0) {
    result.push('低光照');
  }
  if ((flag & ALARM_FLAG_HIGH_CO2) !== 0) {
    result.push('高CO2');
  }
  if ((flag & ALARM_FLAG_LOW_NITROGEN) !== 0) {
    result.push('低氮');
  }
  if ((flag & ALARM_FLAG_LOW_PHOSPHORUS) !== 0) {
    result.push('低磷');
  }
  return result;
}

/**
 * 返回 `setTimeout` 包装的 Promise。
 * @param ms 延迟毫秒数
 */
export function sleep(ms: number): Promise<void> {
  return new Promise<void>((resolve) => {
    setTimeout(resolve, ms);
  });
}

/**
 * 将参数对象转为 `?k=v&k2=v2` 形式。
 * 空对象返回 `''`；值为 `undefined` 时跳过。
 */
export function buildQueryString(params: Record<string, string | number | undefined>): string {
  const parts: string[] = [];
  const keys = Object.keys(params);
  for (let i = 0; i < keys.length; i++) {
    const k = keys[i];
    const v = params[k];
    if (v === undefined) {
      continue;
    }
    parts.push(encodeURIComponent(k) + '=' + encodeURIComponent(String(v)));
  }
  if (parts.length === 0) {
    return '';
  }
  return '?' + parts.join('&');
}

/**
 * 判断入参是否为原生网络层错误（`@ohos.net.http` 抛出的 `BusinessError`）。
 * 当前实现基于"`err` 含 `code` 属性且 `code` 为数字"的最小判定。
 */
export function isNetworkError(err: unknown): boolean {
  if (err === null || err === undefined) {
    return false;
  }
  if (typeof err !== 'object') {
    return false;
  }
  const obj = err as Record<string, unknown>;
  const code = obj['code'];
  return typeof code === 'number';
}

/** 返回当前毫秒时间戳（`Date.now()` 包装）。 */
export function nowMs(): number {
  return Date.now();
}
