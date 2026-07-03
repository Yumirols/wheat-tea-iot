import { describe, beforeEach, it, expect } from '@ohos/hypium';
import { CommandService } from '../main/ets/services/CommandService';
import { CacheManager } from '../main/ets/common/CacheManager';

/**
 * CommandService 单元测试。
 *
 * 覆盖契约：
 * - send 在缓存为空（设备未在缓存中）时**放行**到 HTTP（不抛 'Device offline'）
 *   这是"缓存未命中时不做悲观阻断"的设计意图验证
 * - send 抛出的网络错误不应是 'Device offline'（验证前置校验逻辑未被错误触发）
 *
 * 注：缓存命中设备离线的路径需要预填充 DeviceService 模块级 cachedDevices
 * （需调用 DeviceService.getDeviceList，该路径需 HTTP）。本轮测试专注于
 * "缓存未命中放行"行为——可在无后端环境下验证前置校验通过。
 */
export default function commandServiceTest() {
  describe('CommandService', () => {
    beforeEach(() => {
      CacheManager.clear();
    });

    it('send_when_device_not_in_cache_proceeds_to_http_not_throwing_Device_offline', 0, async () => {
      // 验证：缓存中无该设备时，前置校验放行（不抛 'Device offline'）
      // 测试环境无后端，HTTP 阶段会失败，但失败原因不是 'Device offline'
      let thrownError: Error | null = null;
      try {
        await CommandService.send('unknown_device', 'led ON');
      } catch (e) {
        thrownError = e as Error;
      }

      // 必须抛错（因为无后端 HTTP 会失败）
      expect(thrownError !== null).assertTrue();
      // 但抛错的 message **不**应是前置校验的 'Device offline'
      // 实际抛出的是网络/业务错误（如 'HTTP ...' 或 'JSON parse error' 等）
      if (thrownError !== null) {
        expect(thrownError.message === 'Device offline').assertFalse();
      }
    });

    it('getLogs_passes_through_to_http_without_cache', 0, async () => {
      // 验证：getLogs 不写缓存，调用即触发 HTTP（无后端应抛网络错）
      let thrownError: Error | null = null;
      try {
        await CommandService.getLogs('dev_001');
      } catch (e) {
        thrownError = e as Error;
      }

      // 无后端环境应失败
      expect(thrownError !== null).assertTrue();
      // 不应是 cache 相关错误
      if (thrownError !== null) {
        expect(thrownError.message.indexOf('cache')).assertEqual(-1);
      }
    });

    it('getLogs_with_multiple_params_proceeds_to_http', 0, async () => {
      // 验证：getLogs 传多个参数时仍走 HTTP（不抛 Device offline 等前置校验伪阳性）
      let thrownError: Error | null = null;
      try {
        await CommandService.getLogs('dev_001', 'manual', '2026-07-01', '2026-07-03', 1, 20);
      } catch (e) {
        thrownError = e as Error;
      }

      expect(thrownError !== null).assertTrue();
      // 错误不应是 Device offline（仅 send 有前置校验）
      if (thrownError !== null) {
        expect(thrownError.message === 'Device offline').assertFalse();
      }
    });
  });
}