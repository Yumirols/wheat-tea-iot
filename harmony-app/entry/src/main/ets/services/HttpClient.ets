/**
 * HTTP 业务门面层。
 *
 * 在 `common/api.ets` 原始传输层之上叠加：
 * - 注入 `X-Api-Key` 鉴权头
 * - 拼接 `BASE_URL + path`
 * - JSON 序列化/反序列化
 * - GET 路径的指数退避重试（POST 非幂等，不重试）
 * - 业务错误码透传（不抛业务异常）
 *
 * 调用方：所有 `*Service`（SensorService / DiseaseService / ...）。
 */

import { ApiResponse, TextResult, BinaryResult, RetryPolicyConfig } from '../common/models';
import { API_BASE_URL, API_PATH_PREFIX, API_KEY, HEADER_API_KEY } from '../common/constants';
import { DEFAULT_RETRY } from '../common/RetryPolicy';
import { request, requestRaw } from '../common/api';
import { isNetworkError, sleep, buildQueryString } from '../common/utils';

/** 完整基础 URL（含 `/api/v1` 前缀），供后续 `ImageService` 等模块引用。 */
export const BASE_URL: string = API_BASE_URL + API_PATH_PREFIX;

/** API Key，供后续 `ImageService` 上传头注入时引用。 */
export const HEADER_KEY: string = API_KEY;

export interface StatusCodeHolder {
  statusCode: number;
}

/**
 * 指数退避重试包装（泛型：兼容 TextResult 与 BinaryResult）。
 * - 命中 `policy.retryOn` 中状态码：进入下一轮（最后一轮直接抛错）
 * - 网络异常且未到末轮：进入下一轮（退避后重试）
 * - 其它情况：返回结果或抛出错误
 */
async function withRetry<T extends StatusCodeHolder>(
  operation: () => Promise<T>,
  policy: RetryPolicyConfig = DEFAULT_RETRY
): Promise<T> {
  for (let attempt = 0; attempt <= policy.maxRetries; attempt++) {
    try {
      const result = await operation();
      if (policy.retryOn.includes(result.statusCode)) {
        if (attempt === policy.maxRetries) {
          throw new Error(`HTTP ${result.statusCode} after ${policy.maxRetries} retries`);
        }
      } else {
        return result;
      }
    } catch (err) {
      if (!isNetworkError(err as Object) || attempt === policy.maxRetries) {
        throw err as Error;
      }
    }
    const delay = Math.min(
      policy.baseDelayMs * Math.pow(2, attempt),
      policy.maxDelayMs
    );
    await sleep(delay);
  }
  throw new Error('Retry exhausted');
}

/**
 * GET 业务方法。
 * 自动注入 `X-Api-Key`、拼接 `BASE_URL + path + queryString`、JSON 解析、重试 3 次。
 */
export function get<T>(path: string, params?: Record<string, string | number | undefined>): Promise<ApiResponse<T>> {
  const queryString: string = buildQueryString(params ?? {});
  const url: string = BASE_URL + path + queryString;
  const headers: Record<string, string> = {};
  headers[HEADER_API_KEY] = HEADER_KEY;

  return withRetry(() => {
    return request(url, {
      method: 'GET',
      headers: headers
    });
  }).then((text: TextResult) => {
    try {
      const parsed = JSON.parse(text.rawBody) as ApiResponse<T>;
      return parsed;
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      throw new Error(`JSON parse error: ${msg}`);
    }
  });
}

/**
 * POST 业务方法.
 * 自动注入 `X-Api-Key` 与 `Content-Type: application/json`、JSON 序列化/反序列化。
 * **不**触发重试（POST 非幂等）。
 */
export function post<T>(path: string, body?: object): Promise<ApiResponse<T>> {
  const url: string = BASE_URL + path;
  const headers: Record<string, string> = {};
  headers[HEADER_API_KEY] = HEADER_KEY;
  headers['Content-Type'] = 'application/json';
  const extraData: string = body !== undefined ? JSON.stringify(body) : '';

  return request(url, {
    method: 'POST',
    headers: headers,
    body: extraData
  }).then((text: TextResult) => {
    try {
      const parsed = JSON.parse(text.rawBody) as ApiResponse<T>;
      return parsed;
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      throw new Error(`JSON parse error: ${msg}`);
    }
  });
}

/**
 * GET 二进制方法。
 * 内部调用 `api.requestRaw()`，返回 `ArrayBuffer`。
 * 网络错误或 `statusCode ∈ retryOn` 时进入指数退避重试。
 */
export function getRaw(path: string, params?: Record<string, string | number | undefined>): Promise<ArrayBuffer> {
  const queryString: string = buildQueryString(params ?? {});
  const url: string = BASE_URL + path + queryString;
  const headers: Record<string, string> = {};
  headers[HEADER_API_KEY] = HEADER_KEY;

  return withRetry(() => {
    return requestRaw(url, {
      method: 'GET',
      headers: headers
    });
  }).then((bin: BinaryResult) => {
    return bin.rawBody;
  });
}
