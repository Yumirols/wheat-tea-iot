/**
 * 轮询调度器（真实实现）。
 *
 * 基于**递归 `setTimeout`** 实现串行调度（**不并发**）：
 * - 每个 `key` 关联一个 `PollingTask`，`start(key, fn, intervalMs)` 注册首个 tick
 * - 每个 tick 在 `setTimeout` 触发后执行 `task.fn()`
 * - 上一个 tick 的 Promise resolve/reject 后才调度下一个 `setTimeout`
 *   - 错误被 `catch` 后**不**中断轮询（`console.error` 后继续）
 *
 * 暂停 / 恢复（应用前后台切换）：
 * - `suspendAll()`：对所有任务 `clearTimeout(timerId)` 并置 `suspended = true`（保留任务引用）
 * - `resumeAll()`：对所有 `suspended === true` 的任务重置 `suspended = false` 并 `scheduleNext(key)` 重新注册
 *
 * 串行模式约束：
 * - `start` 中**不**立即执行 `fn`；首个 tick 在首个 `setTimeout` 触发后执行
 * - 必须在调用 `task.fn()` **之前**将 `task.timerId` 置 `null`（避免 `stop` 时 `clearTimeout(null)` 报错）
 *
 * 公开签名与 R1 占位完全一致（`EntryAbility` 调用点不破坏）。
 *
 * ArkTS 注意事项：
 * - `setTimeout` 在 HarmonyOS 中返回 `number`（`timerId`）
 * - `console` 为全局可访问
 * - 递归 `setTimeout` 通过 `Promise.then` / `catch` 链异步展开，不存在调用栈累积
 */

import { PollingCallback } from '../common/models';

/** 轮询任务条目（模块内私有）。 */
interface PollingTask {
  running: boolean;
  suspended: boolean;
  fn: PollingCallback;
  intervalMs: number;
  timerId: number | null;
}

/** 全局任务表。 */
const tasks: Map<string, PollingTask> = new Map();

/**
 * 私有：注册下一个 `setTimeout`。
 *
 * - 若 `task` 不存在或 `suspended === true` 直接返回
 * - 否则 `task.timerId = setTimeout(() => { tick(key); }, task.intervalMs)`
 */
function scheduleNext(key: string): void {
  const task: PollingTask | undefined = tasks.get(key);
  if (task === undefined) {
    return;
  }
  if (task.suspended) {
    return;
  }
  task.timerId = setTimeout(() => {
    tick(key);
  }, task.intervalMs);
}

/**
 * 私有：执行一次 tick（递归链的当前帧）。
 *
 * - 已被 `stop` / `suspend` 则直接返回
 * - `task.timerId = null`（**必须**在 `task.fn()` 之前置位，避免 `stop` 期间 `clearTimeout(null)` 报错）
 * - 调用 `task.fn()`：
 *   - `.then` / `.catch` 的 `finally` 中再次检查 `tasks.get(key)` 是否仍存在且未 suspended
 *   - 条件满足则递归调用 `scheduleNext(key)` 调度下一 tick（**串行**模式）
 *   - 错误被 `console.error` 记录但**不**中断轮询
 */
function tick(key: string): void {
  const task: PollingTask | undefined = tasks.get(key);
  if (task === undefined) {
    return;
  }
  if (task.suspended) {
    return;
  }

  // 必须在调用 fn() 之前清空 timerId，避免 stop 期间 clearTimeout(null) 报错
  task.timerId = null;

  // 串行链：上一 tick resolve/reject 后再 scheduleNext 下一 tick
  task.fn()
    .then(() => {
      // 成功：继续
    })
    .catch((err: Object) => {
      // 错误：记录但**不**中断轮询
      console.error('PollingManager tick error', JSON.stringify(err));
    })
    .finally(() => {
      const after: PollingTask | undefined = tasks.get(key);
      if (after === undefined) {
        return;
      }
      if (after.suspended) {
        return;
      }
      scheduleNext(key);
    });
}

/**
 * 注册一个轮询任务。
 *
 * - 若 `key` 已存在则先 `stop(key)` 清理旧任务
 * - 创建 `PollingTask` 并 `tasks.set(key, task)`
 * - 调用 `scheduleNext(key)` 注册首个 `setTimeout`（**不**立即执行 `fn`）
 *
 * @param key 任务键（唯一标识）
 * @param fn 轮询回调（异步无参无返回）
 * @param intervalMs 轮询间隔（毫秒）
 */
function start(key: string, fn: PollingCallback, intervalMs: number): void {
  if (tasks.has(key)) {
    stop(key);
  }
  const task: PollingTask = {
    running: true,
    suspended: false,
    fn: fn,
    intervalMs: intervalMs,
    timerId: null
  };
  tasks.set(key, task);
  scheduleNext(key);
}

/**
 * 停止并移除指定 key 的轮询任务。
 *
 * - `clearTimeout(timerId)` 后 `tasks.delete(key)`
 * - 若 `key` 不存在则直接返回
 */
function stop(key: string): void {
  const task: PollingTask | undefined = tasks.get(key);
  if (task === undefined) {
    return;
  }
  if (task.timerId !== null) {
    clearTimeout(task.timerId);
  }
  tasks.delete(key);
}

/**
 * 停止并清空所有轮询任务。
 */
function stopAll(): void {
  const keys: string[] = Array.from(tasks.keys());
  for (let i = 0; i < keys.length; i++) {
    const k = keys[i];
    const task: PollingTask | undefined = tasks.get(k);
    if (task !== undefined && task.timerId !== null) {
      clearTimeout(task.timerId);
    }
  }
  tasks.clear();
}

/**
 * 暂停所有轮询任务。
 *
 * - 对所有 `task.timerId !== null` 的项 `clearTimeout`，将 `task.timerId` 置 `null`
 * - 对所有 task 置 `task.suspended = true`
 * - **保留** task 引用（不 `delete`），供 `resumeAll` 恢复
 *
 * 用途：`EntryAbility.onBackground`（App 切后台时暂停所有轮询）
 */
function suspendAll(): void {
  const keys: string[] = Array.from(tasks.keys());
  for (let i = 0; i < keys.length; i++) {
    const k = keys[i];
    const task: PollingTask | undefined = tasks.get(k);
    if (task === undefined) {
      continue;
    }
    if (task.timerId !== null) {
      clearTimeout(task.timerId);
      task.timerId = null;
    }
    task.suspended = true;
  }
}

/**
 * 恢复所有曾被 `suspendAll` 暂停的轮询任务。
 *
 * - 对 `task.suspended === true` 的项：置 `task.suspended = false` 并 `scheduleNext(key)` 重启定时器
 * - 对 `task.suspended === false` 的项不重启
 *
 * 用途：`EntryAbility.onForeground`（App 切回前台时恢复所有轮询）
 */
function resumeAll(): void {
  const keys: string[] = Array.from(tasks.keys());
  for (let i = 0; i < keys.length; i++) {
    const k = keys[i];
    const task: PollingTask | undefined = tasks.get(k);
    if (task === undefined) {
      continue;
    }
    if (task.suspended) {
      task.suspended = false;
      scheduleNext(k);
    }
  }
}

export interface PollingManagerType {
  start: (key: string, fn: PollingCallback, intervalMs: number) => void;
  stop: (key: string) => void;
  stopAll: () => void;
  suspendAll: () => void;
  resumeAll: () => void;
}

export const PollingManager: PollingManagerType = {
  start: start,
  stop: stop,
  stopAll: stopAll,
  suspendAll: suspendAll,
  resumeAll: resumeAll
};
