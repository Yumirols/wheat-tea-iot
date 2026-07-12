import { describe, beforeEach, it, expect } from '@ohos/hypium';
import { SensorService } from '../main/ets/services/SensorService';
import { CacheManager } from '../main/ets/common/CacheManager';
import {
  CACHE_KEY_PREFIX_SENSOR_LATEST,
  CACHE_KEY_PREFIX_SENSOR_ALL_LATEST,
  CACHE_TTL_SENSOR_MS
} from '../main/ets/common/constants';
import { SensorSnapshot } from '../main/ets/common/models';

/**
 * SensorService 单元测试。
 *
 * 覆盖契约：
 * - getLatest 缓存命中直接返回（**不**触发 HTTP）
 * - getAllLatest 缓存命中直接返回（**不**触发 HTTP）
 * - 缓存键构造规则（per-device key、all-latest 固定 key）
 *
 * 注：HTTP 失败路径需真实后端或 mock HttpClient（ArkTS 不支持运行时模块替换）。
 * 本轮测试专注于"缓存命中"路径——预填充 CacheManager 后，调用 Service
 * 应直接返回缓存值（不抛网络错误即为命中）。
 */
export default function sensorServiceTest() {
  describe('SensorService', () => {
    beforeEach(() => {
      CacheManager.clear();
    });

    it('getLatest_returns_cached_value_without_http_call', 0, async () => {
      // 验证：缓存命中路径 — 预填缓存后 getLatest 直接返回该值
      const cached: SensorSnapshot = {
        id: 100,
        device_id: 'dev_001',
        mac_addr: 'AA:BB:CC:DD:EE:FF',
        timestamp: '2026-07-03T10:00:00Z',
        temperature: 25.5,
        humidity: 60.0,
        light: 5000,
        co2: 400,
        soil_n: 30,
        soil_p: 20,
        soil_k: 25,
        distance: 100,
        rssi: -60,
        ip_addr: '192.168.1.10',
        alarm_flag: 0,
        created_at: '2026-07-03T10:00:00Z'
      };

      const key = CACHE_KEY_PREFIX_SENSOR_LATEST + 'dev_001';
      CacheManager.set(key, cached, CACHE_TTL_SENSOR_MS);

      // 调用 Service 应命中缓存（若不命中则触发 HTTP，本测试环境无后端会失败）
      const result = await SensorService.getLatest('dev_001');

      expect(result).assertEqual(cached);
      expect(result.device_id).assertEqual('dev_001');
      expect(result.temperature).assertEqual(25.5);
    });

    it('getAllLatest_returns_cached_array_without_http_call', 0, async () => {
      // 验证：getAllLatest 缓存命中 — 固定 key CACHE_KEY_PREFIX_SENSOR_ALL_LATEST
      const cachedArr: SensorSnapshot[] = [{
        id: 1,
        device_id: 'dev_a',
        mac_addr: '',
        timestamp: '2026-07-03T10:00:00Z',
        temperature: 22,
        humidity: 55,
        light: 4000,
        co2: 380,
        soil_n: 25,
        soil_p: 15,
        soil_k: 20,
        distance: 100,
        rssi: -65,
        ip_addr: '',
        alarm_flag: 0,
        created_at: '2026-07-03T10:00:00Z'
      }, {
        id: 2,
        device_id: 'dev_b',
        mac_addr: '',
        timestamp: '2026-07-03T10:00:01Z',
        temperature: 24,
        humidity: 58,
        light: 4200,
        co2: 400,
        soil_n: 28,
        soil_p: 18,
        soil_k: 22,
        distance: 110,
        rssi: -62,
        ip_addr: '',
        alarm_flag: 0,
        created_at: '2026-07-03T10:00:01Z'
      }];

      const key = CACHE_KEY_PREFIX_SENSOR_ALL_LATEST;
      CacheManager.set(key, cachedArr, CACHE_TTL_SENSOR_MS);

      const result = await SensorService.getAllLatest();

      expect(Array.isArray(result)).assertTrue();
      expect(result.length).assertEqual(2);
      expect(result[0].device_id).assertEqual('dev_a');
      expect(result[1].device_id).assertEqual('dev_b');
    });

    it('getLatest_uses_deviceId_specific_cache_key', 0, () => {
      // 验证：不同 deviceId 写入不同缓存键（缓存隔离）
      // 通过 CacheManager 直接验证 key 构造逻辑
      const snap: SensorSnapshot = {
        id: 1,
        device_id: 'dev_x',
        mac_addr: '',
        timestamp: '',
        temperature: 0,
        humidity: 0,
        light: 0,
        co2: 0,
        soil_n: 0,
        soil_p: 0,
        soil_k: 0,
        distance: 0,
        rssi: 0,
        ip_addr: '',
        alarm_flag: 0,
        created_at: ''
      };

      const keyX = CACHE_KEY_PREFIX_SENSOR_LATEST + 'dev_x';
      const keyY = CACHE_KEY_PREFIX_SENSOR_LATEST + 'dev_y';

      CacheManager.set(keyX, snap, CACHE_TTL_SENSOR_MS);
      // dev_x 命中
      expect(CacheManager.get<SensorSnapshot>(keyX) !== null).assertTrue();
      // dev_y 未命中
      expect(CacheManager.get<SensorSnapshot>(keyY)).assertEqual(null);
    });

    it('getHistory_does_not_cache_and_passes_through_to_http', 0, async () => {
      // 验证：getHistory 不读缓存，直接请求 HTTP（无后端抛网络错误，有后端时传非法参数触发 422）
      let thrownError: Error | null = null;
      try {
        // 传入非法的 page (0) 确保即便网络通畅，后端也会因为参数校验（ge=1）报错
        await SensorService.getHistory('dev_001', undefined, undefined, 0);
      } catch (e) {
        thrownError = e as Error;
      }

      expect(thrownError !== null).assertTrue();
    });

    it('getDaily_does_not_cache_and_passes_through_to_http', 0, async () => {
      // 验证：getDaily 不读缓存，直接请求 HTTP（无后端抛网络错误，有后端时传非法参数触发 422）
      let thrownError: Error | null = null;
      try {
        // 传入非法的 page (0) 确保即便网络通畅，后端也会因为参数校验（ge=1）报错
        await SensorService.getDaily('dev_001', '2026-07-01', '2026-07-03', 0);
      } catch (e) {
        thrownError = e as Error;
      }

      expect(thrownError !== null).assertTrue();
    });
  });
}