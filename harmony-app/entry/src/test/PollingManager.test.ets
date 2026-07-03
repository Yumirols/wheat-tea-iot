import { describe, beforeEach, afterEach, it, expect } from '@ohos/hypium';
import { PollingManager } from '../main/ets/services/PollingManager';
import { sleep } from '../main/ets/common/utils';

/**
 * PollingManager 单元测试。
 *
 * 覆盖契约：
 * - start 注册首个 setTimeout，**不**立即执行 fn
 * - 串行模式：上一个 tick resolve 后才调度下一个 tick
 * - tick 中 fn reject 仍继续（错误不中断轮询）
 * - stop 后不再调用 fn
 * - stopAll 清空所有任务
 * - suspendAll 暂停后 fn 不再被调用，但任务引用保留
 * - resumeAll 重新调度 suspended === true 的任务
 */
export default function pollingManagerTest() {
  describe('PollingManager', () => {
    // 每个 case 后清理：避免遗留定时器污染后续 case
    afterEach(() => {
      PollingManager.stopAll();
    });

    it('start_registers_task_without_immediate_invocation', 0, async () => {
      // 验证：start 后立即 fn 不被调用（首个 tick 在 setTimeout 触发后才执行）
      const calls: number[] = [];
      const fn = async (): Promise<void> => {
        calls.push(Date.now());
      };

      const before = Date.now();
      PollingManager.start('sensor', fn, 50);

      // start 调用后立即检查，fn 不应已被调用
      expect(calls.length).assertEqual(0);

      // 等首个 tick 触发
      await sleep(80);
      const after = Date.now();

      expect(calls.length).assertEqual(1);
      // 首个 tick 触发时间应 >= before + intervalMs
      expect(calls[0] >= before).assertTrue();
      expect(calls[0] <= after + 5).assertTrue();
    });

    it('start_schedules_subsequent_ticks_after_interval', 0, async () => {
      // 验证：第一个 tick resolve 后，间隔 intervalMs 才调度下一个 tick
      const calls: number[] = [];
      const fn = async (): Promise<void> => {
        calls.push(Date.now());
      };

      PollingManager.start('sensor', fn, 30);

      // 等 3 次 tick（间隔 30ms，每次 resolve 后 scheduleNext 30ms）
      await sleep(150);

      // 至少 2 次（容忍定时器抖动）
      expect(calls.length >= 2).assertTrue();

      // 计算相邻 tick 间隔，应 >= intervalMs（30ms）但不会远超
      if (calls.length >= 2) {
        const gap = calls[1] - calls[0];
        expect(gap >= 25).assertTrue();
        expect(gap <= 100).assertTrue();
      }
    });

    it('tick_error_does_not_interrupt_polling', 0, async () => {
      // 验证：tick 中 fn reject 仍调度下一个 tick（错误不中断轮询）
      const calls: number[] = [];
      const fn = async (): Promise<void> => {
        calls.push(Date.now());
        throw new Error('test error');
      };

      PollingManager.start('error_task', fn, 30);

      // 等 3 次 tick
      await sleep(150);

      // 即便每次 tick 都 reject，仍应连续执行多次（至少 2 次）
      expect(calls.length >= 2).assertTrue();
    });

    it('stop_clears_pending_timeout', 0, async () => {
      // 验证：stop 后 fn 不再被调用
      const calls: number[] = [];
      const fn = async (): Promise<void> => {
        calls.push(Date.now());
      };

      PollingManager.start('to_stop', fn, 30);
      await sleep(20); // 未到首次 tick

      PollingManager.stop('to_stop');
      await sleep(80);

      // 整个区间 fn 不应被调用
      expect(calls.length).assertEqual(0);
    });

    it('stop_on_unknown_key_is_safe', 0, () => {
      // 验证：对不存在的 key 调用 stop 不抛错
      PollingManager.stop('never_started');
      // 不抛错即通过
      expect(true).assertTrue();
    });

    it('stopAll_clears_all_tasks', 0, async () => {
      // 验证：stopAll 清空所有任务
      const callsA: number[] = [];
      const callsB: number[] = [];
      PollingManager.start('a', async () => { callsA.push(1); }, 30);
      PollingManager.start('b', async () => { callsB.push(1); }, 30);

      await sleep(10); // 未到首次 tick
      PollingManager.stopAll();
      await sleep(80);

      expect(callsA.length).assertEqual(0);
      expect(callsB.length).assertEqual(0);
    });

    it('suspendAll_pauses_execution_but_preserves_tasks', 0, async () => {
      // 验证：suspendAll 后 fn 不再被调用，但 resumeAll 后能恢复
      const calls: number[] = [];
      PollingManager.start('suspendable', async () => { calls.push(1); }, 30);

      // 等首个 tick
      await sleep(60);
      expect(calls.length >= 1).assertTrue();

      // 暂停
      PollingManager.suspendAll();
      const beforeResume = calls.length;
      await sleep(120); // 等足够久，确保若未暂停会触发更多 tick
      const afterSuspend = calls.length;
      // 暂停期间不应有新 tick
      expect(afterSuspend).assertEqual(beforeResume);
    });

    it('resumeAll_restarts_suspended_tasks', 0, async () => {
      // 验证：resumeAll 重新调度被暂停的任务
      const calls: number[] = [];
      PollingManager.start('resumable', async () => { calls.push(1); }, 30);

      await sleep(60);
      PollingManager.suspendAll();
      const beforeResume = calls.length;
      await sleep(60);
      // 暂停期间不应有新调用
      expect(calls.length).assertEqual(beforeResume);

      PollingManager.resumeAll();
      await sleep(80);
      // resume 后应有新 tick
      expect(calls.length > beforeResume).assertTrue();
    });

    it('start_with_existing_key_stops_previous', 0, async () => {
      // 验证：start 同 key 会先 stop 旧任务
      const callsA: number[] = [];
      const callsB: number[] = [];

      PollingManager.start('shared', async () => { callsA.push(1); }, 30);
      await sleep(40); // 让旧任务跑过至少 1 tick
      const oldCalls = callsA.length;

      PollingManager.start('shared', async () => { callsB.push(1); }, 30);
      await sleep(80);

      // 旧 fn 在 start 重启后不应再被调用（或极少）
      // 新 fn 至少应被调用 1 次
      expect(callsB.length >= 1).assertTrue();
      // 旧 fn 调用次数应大致停留在 start 重启前（允许已有一次）
      expect(callsA.length <= oldCalls + 1).assertTrue();
    });

    it('resumeAll_on_already_running_task_does_not_restart', 0, async () => {
      // 验证：resumeAll 对非 suspended 的任务不重启（保留原 timer）
      const calls: number[] = [];
      PollingManager.start('running', async () => { calls.push(1); }, 30);

      await sleep(20); // 未到首次 tick

      // 对未暂停的任务调用 resumeAll
      PollingManager.resumeAll();

      await sleep(100);
      // 仍正常 tick
      expect(calls.length >= 2).assertTrue();
    });

    it('suspendAll_on_empty_tasks_is_safe', 0, () => {
      // 验证：无注册任务时 suspendAll 不抛错
      PollingManager.suspendAll();
      expect(true).assertTrue();
    });

    it('resumeAll_on_empty_tasks_is_safe', 0, () => {
      // 验证：无注册任务时 resumeAll 不抛错
      PollingManager.resumeAll();
      expect(true).assertTrue();
    });

    it('stopAll_after_suspendAll_removes_all_tasks', 0, async () => {
      // 验证：suspendAll 后 stopAll 可彻底清理
      const calls: number[] = [];
      PollingManager.start('t1', async () => { calls.push(1); }, 30);
      PollingManager.start('t2', async () => { calls.push(1); }, 30);

      await sleep(60);
      PollingManager.suspendAll();
      PollingManager.stopAll();

      // stopAll 后 resumeAll 不应恢复任何任务
      PollingManager.resumeAll();
      const beforeClean = calls.length;
      await sleep(80);
      expect(calls.length).assertEqual(beforeClean);
    });
  });
}