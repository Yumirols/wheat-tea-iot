/**
 * 默认重试策略常量定义。
 *
 * 仅导出 `DEFAULT_RETRY` 常量，HTTP 客户端在 `withRetry` 内部按此配置
 * 决定是否进入下一轮退避重试。
 *
 * `timeoutMs` 字段当前为契约保留字段（参见 `models.ets` 中 `RetryPolicyConfig`
 * 注释）；重试循环暂不直接消费该值调整超时，仅作为"时长相关字段"的统一基线。
 */

import { RetryPolicyConfig } from './models';
import { RETRY_BASE_DELAY_MS, RETRY_MAX_DELAY_MS, RETRY_MAX_RETRIES, RETRY_STATUS_CODES, DEFAULT_TIMEOUT_MS } from './constants';

export const DEFAULT_RETRY: RetryPolicyConfig = {
  maxRetries: RETRY_MAX_RETRIES,
  baseDelayMs: RETRY_BASE_DELAY_MS,
  maxDelayMs: RETRY_MAX_DELAY_MS,
  retryOn: RETRY_STATUS_CODES,
  timeoutMs: DEFAULT_TIMEOUT_MS
};
