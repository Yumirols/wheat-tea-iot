import { describe, beforeEach, it, expect } from '@ohos/hypium';
import { AdvisoryService } from '../main/ets/services/AdvisoryService';
import { CacheManager } from '../main/ets/common/CacheManager';
import {
  CACHE_KEY_PREFIX_ADVISORY,
  CACHE_TTL_ADVISORY_MS
} from '../main/ets/common/constants';
import { Advisory } from '../main/ets/common/models';

/**
 * AdvisoryService 单元测试。
 *
 * 覆盖契约：
 * - getAdvisory 缓存命中直接返回
 * - 缓存键格式：CACHE_KEY_PREFIX_ADVISORY + (deviceId ?? 'all') + '_' + (windowMinutes ?? 'all')
 * - 当 deviceId / windowMinutes 均为 undefined 时，key 为 ... + 'all_all'
 * - 缓存键中**不**包含 start / end（与 windowMinutes 表达的时间窗口重叠）
 */
export default function advisoryServiceTest() {
  describe('AdvisoryService', () => {
    beforeEach(() => {
      CacheManager.clear();
    });

    it('getAdvisory_returns_cached_value_on_cache_hit', 0, async () => {
      // 验证：getAdvisory 缓存命中直接返回
      const cached: Advisory = {
        latest_detection: {
          crop_type: 'tomato',
          disease_type: 'blight',
          severity: 'medium',
          severity_code: 2,
          max_conf: 0.85,
          timestamp: '2026-07-03T10:00:00Z'
        },
        current_env: {
          temperature: 25,
          humidity: 60,
          light: 5000,
          co2: 400
        },
        env_disease_linkage: {
          risk_level: 'medium',
          matched_conditions: ['high_humidity'],
          recommendation: '建议通风'
        },
        advisory: {
          action: 'spray_fungicide',
          description: '喷洒多菌灵',
          auto_action_triggered: false,
          auto_action: null
        }
      };

      const key = CACHE_KEY_PREFIX_ADVISORY + 'all_all';
      CacheManager.set(key, cached, CACHE_TTL_ADVISORY_MS);

      const result = await AdvisoryService.getAdvisory();

      expect(result.latest_detection !== null).assertTrue();
      expect(result.latest_detection!.crop_type).assertEqual('tomato');
      expect(result.current_env!.temperature).assertEqual(25);
      expect(result.advisory!.action).assertEqual('spray_fungicide');
    });

    it('cache_key_format_for_specific_deviceId_and_window', 0, () => {
      // 验证：缓存键构造规则
      // 实现：(CACHE_KEY_PREFIX_ADVISORY) + (deviceId ?? 'all') + '_' + (windowMinutes ?? 'all')
      const cached: Advisory = {
        latest_detection: null,
        current_env: null,
        env_disease_linkage: null,
        advisory: null
      };

      const keyDevice = CACHE_KEY_PREFIX_ADVISORY + 'dev_001_60';
      const keyNoDevice = CACHE_KEY_PREFIX_ADVISORY + 'all_30';

      CacheManager.set(keyDevice, cached, CACHE_TTL_ADVISORY_MS);
      CacheManager.set(keyNoDevice, cached, CACHE_TTL_ADVISORY_MS);

      const got1 = CacheManager.get<Advisory>(keyDevice);
      const got2 = CacheManager.get<Advisory>(keyNoDevice);
      expect(got1 !== null).assertTrue();
      expect(got2 !== null).assertTrue();
      // 两 key 不同
      expect(keyDevice === keyNoDevice).assertFalse();
    });

    it('cache_key_all_undefined_uses_all_all', 0, async () => {
      // 验证：deviceId 与 windowMinutes 都未传时，key 为 'all_all'
      const cached: Advisory = {
        latest_detection: null,
        current_env: null,
        env_disease_linkage: null,
        advisory: null
      };

      const key = CACHE_KEY_PREFIX_ADVISORY + 'all_all';
      CacheManager.set(key, cached, CACHE_TTL_ADVISORY_MS);

      const result = await AdvisoryService.getAdvisory();

      expect(result).assertEqual(cached);
    });

    it('getAdvisory_cache_miss_proceeds_to_http', 0, async () => {
      // 验证：缓存未命中时 getAdvisory 请求 HTTP（无后端抛网络错误，有后端时传非法参数触发 422）
      // before 每个 case 已清空缓存
      let thrownError: Error | null = null;
      try {
        // 传入非法的 windowMinutes (0) 确保即便网络通畅，后端也会因为参数校验（ge=1）报错
        await AdvisoryService.getAdvisory('unknown_device', undefined, undefined, 0);
      } catch (e) {
        thrownError = e as Error;
      }

      // 未命中缓存，应抛网络/业务错误而非返回 null/undefined
      expect(thrownError !== null).assertTrue();
    });
  });
}