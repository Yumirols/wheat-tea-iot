/**
 * 设备控制命令服务。
 *
 * 提供两类能力：
 * - `send(deviceId, command, source?, operator?)`：下发控制命令（含离线前置校验 + 失败路径缓存刷新）
 * - `getLogs(...)`：查询控制日志分页（**不**缓存）
 *
 * 关键行为：
 * - 前置校验：调用 `DeviceService.getCachedDevices(deviceId)` 检查 `online === false`；
 *   若缓存中显示设备离线，**直接** `throw new Error('Device offline')` 不发送请求
 * - 缓存未命中（设备不在缓存中）时**放行**——远程可能已更新状态
 * - 失败路径刷新：当后端返回 `code === ERR_CODE_DEVICE_OFFLINE (1003)` 时，
 *   先 `await DeviceService.refreshDevices(deviceId)` 刷新缓存，**再**以
 *   `resp.message` 抛 `Error`（保持与其它业务错误一致的抛错语义）
 * - HTTP 层抛错（网络异常）时**不**主动刷新缓存（设备可能仅是网络问题）
 *
 * 缓存：仅依赖 `DeviceService` 的设备缓存；`send` / `getLogs` 结果均不缓存
 *
 * 模块依赖：单向依赖 `DeviceService`（`DeviceService` 不引用本服务，**无循环**）
 */

import { CommandResponse, CommandLog, PaginatedData, ApiResponse } from '../common/models';
import { ERR_CODE_DEVICE_OFFLINE } from '../common/constants';
import { post as httpPost, get as httpGet } from './HttpClient';
import { DeviceService } from './DeviceService';

/**
 * 发送设备控制命令。
 *
 * 流程：
 * 1. 前置校验：查 `DeviceService.getCachedDevices(deviceId)`，若发现设备 `online === false` 直接 `throw new Error('Device offline')`
 * 2. 构造请求体 `{ device_id, command, source?, operator? }`（`undefined` 字段由 `JSON.stringify` 自然忽略）
 * 3. `POST /command/send`
 * 4. `code === 0 && data !== null` → 返回 `data`
 * 5. `code === 1003` → `await DeviceService.refreshDevices(deviceId)` 后抛 `Error(resp.message)`
 * 6. 其它业务错误 → 抛 `Error(resp.message)`
 *
 * @param deviceId 设备 ID
 * @param command 命令字符串（如 `'led ON'`，参见 `constants.ets` 中 `CMD_*`）
 * @param source 可选命令来源
 * @param operator 可选操作人
 * @returns 命令响应
 * @throws `Error('Device offline')`（前置校验失败）/ `Error(resp.message)`（业务失败，含离线刷新后）/ 网络异常
 */
async function send(
  deviceId: string,
  command: string,
  source?: string,
  operator?: string
): Promise<CommandResponse> {
  // 前置校验：仅检查缓存中明确显示离线的设备
  const cached = DeviceService.getCachedDevices(deviceId);
  for (let i = 0; i < cached.length; i++) {
    const d = cached[i];
    if (d.device_id === deviceId && d.online === false) {
      throw new Error('Device offline');
    }
  }

  // 构造请求体（undefined 字段由 JSON.stringify 自动忽略）
  const body: Record<string, string> = {};
  body['device_id'] = deviceId;
  body['command'] = command;
  if (source !== undefined) {
    body['source'] = source;
  }
  if (operator !== undefined) {
    body['operator'] = operator;
  }

  const resp: ApiResponse<CommandResponse> = await httpPost<CommandResponse>('/command/send', body);

  if (resp.code === 0 && resp.data !== null) {
    return resp.data;
  }

  // 离线：刷新设备缓存后抛错（保证下次读取为最新）
  if (resp.code === ERR_CODE_DEVICE_OFFLINE) {
    await DeviceService.refreshDevices(deviceId);
    throw new Error(resp.message || 'Device offline');
  }

  // 其它业务错误
  throw new Error(resp.message || 'Command send error');
}

/**
 * 控制命令日志分页。
 *
 * - **不**缓存（分页+筛选组合空间大）
 * - 字段 `undefined` 由 `HttpClient.get` 的 `buildQueryString` 自动跳过
 *
 * @param deviceId 可选设备 ID 过滤
 * @param source 可选命令来源过滤
 * @param start 可选开始时间
 * @param end 可选结束时间
 * @param page 可选页码
 * @param pageSize 可选每页条数（映射为 `page_size`）
 * @returns 分页数据
 * @throws 网络/业务异常
 */
async function getLogs(
  deviceId?: string,
  source?: string,
  start?: string,
  end?: string,
  page?: number,
  pageSize?: number
): Promise<PaginatedData<CommandLog>> {
  const queryParams: Record<string, string | number | undefined> = {};
  queryParams['device_id'] = deviceId;
  queryParams['source'] = source;
  queryParams['start'] = start;
  queryParams['end'] = end;
  queryParams['page'] = page;
  queryParams['page_size'] = pageSize;

  const resp: ApiResponse<PaginatedData<CommandLog>> =
    await httpGet<PaginatedData<CommandLog>>('/command/logs', queryParams);

  if (resp.code !== 0 || resp.data === null) {
    throw new Error(resp.message || 'Command logs error');
  }

  return resp.data;
}

export interface CommandServiceType {
  send: (deviceId: string, command: string, source?: string, operator?: string) => Promise<CommandResponse>;
  getLogs: (deviceId?: string, source?: string, start?: string, end?: string, page?: number, pageSize?: number) => Promise<PaginatedData<CommandLog>>;
}

export const CommandService: CommandServiceType = {
  send: send,
  getLogs: getLogs
};
