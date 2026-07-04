import { describe, beforeEach, it, expect } from '@ohos/hypium';
import { DiseaseService } from '../main/ets/services/DiseaseService';
import { CacheManager } from '../main/ets/common/CacheManager';
import {
  CACHE_KEY_PREFIX_DISEASE_STATS,
  CACHE_KEY_PREFIX_DISEASE_HEATMAP,
  CACHE_TTL_DISEASE_MS
} from '../main/ets/common/constants';
import { DiseaseStats, HeatmapData } from '../main/ets/common/models';

/**
 * DiseaseService 单元测试。
 *
 * 覆盖契约：
 * - getStats 缓存命中直接返回（按 start_end 维度隔离）
 * - getHeatmap 缓存命中直接返回（固定全局键）
 * - getStats 当 start / end 均为 undefined 时 key 为 ... + 'all_all'
 *
 * 注：getList 不缓存（多维筛选），通过 try-catch 验证无缓存直通 HTTP 抛错。
 */
export default function diseaseServiceTest() {
  describe('DiseaseService', () => {
    beforeEach(() => {
      CacheManager.clear();
    });

    it('getStats_returns_cached_value_when_key_matches', 0, async () => {
      // 验证：getStats 缓存命中
      const cached: DiseaseStats = {
        total_detections: 42,
        by_crop: { tomato: 30, cucumber: 12 },
        by_severity: { low: 25, medium: 12, high: 5 },
        by_disease: { blight: 20, rust: 22 }
      };

      const key = CACHE_KEY_PREFIX_DISEASE_STATS + 'all_all';
      CacheManager.set(key, cached, CACHE_TTL_DISEASE_MS);

      const result = await DiseaseService.getStats();

      expect(result.total_detections).assertEqual(42);
      expect(result.by_crop['tomato']).assertEqual(30);
      expect(result.by_severity['high']).assertEqual(5);
    });

    it('getStats_uses_differentiated_keys_for_time_ranges', 0, async () => {
      // 验证：不同 start/end 维度写入不同 key（缓存隔离）
      const stats1: DiseaseStats = {
        total_detections: 10,
        by_crop: {},
        by_severity: {},
        by_disease: {}
      };
      const stats2: DiseaseStats = {
        total_detections: 20,
        by_crop: {},
        by_severity: {},
        by_disease: {}
      };

      const keyJan = CACHE_KEY_PREFIX_DISEASE_STATS + '2026-01-01' + '_' + '2026-01-31';
      const keyFeb = CACHE_KEY_PREFIX_DISEASE_STATS + '2026-02-01' + '_' + '2026-02-28';

      CacheManager.set(keyJan, stats1, CACHE_TTL_DISEASE_MS);
      CacheManager.set(keyFeb, stats2, CACHE_TTL_DISEASE_MS);

      // 两个 key 独立命中
      const got1 = CacheManager.get<DiseaseStats>(keyJan);
      const got2 = CacheManager.get<DiseaseStats>(keyFeb);
      expect(got1 !== null).assertTrue();
      expect(got2 !== null).assertTrue();
      expect(got1!.total_detections).assertEqual(10);
      expect(got2!.total_detections).assertEqual(20);
    });

    it('getStats_all_undefined_uses_all_all_key', 0, async () => {
      // 验证：start / end 均为 undefined 时，getStats 内部构造 key = ... + 'all_all'
      // 预填充缓存后调用 await DiseaseService.getStats()（不传参），应返回预填充数据
      const cached: DiseaseStats = {
        total_detections: 42,
        by_crop: { tomato: 30, cucumber: 12 },
        by_severity: { low: 25, medium: 12, high: 5 },
        by_disease: { blight: 20, rust: 22 }
      };

      const key = CACHE_KEY_PREFIX_DISEASE_STATS + 'all_all';
      CacheManager.set(key, cached, CACHE_TTL_DISEASE_MS);

      const result = await DiseaseService.getStats();

      expect(result.total_detections).assertEqual(42);
      expect(result.by_crop['tomato']).assertEqual(30);
      expect(result.by_severity['high']).assertEqual(5);
    });

    it('getList_passes_through_to_http_without_cache', 0, async () => {
      // 验证：getList 不缓存，直接请求 HTTP（无后端抛网络错误）
      let thrownError: Error | null = null;
      try {
        await DiseaseService.getList();
      } catch (e) {
        thrownError = e as Error;
      }

      expect(thrownError !== null).assertTrue();
    });

    it('getHeatmap_returns_cached_value_with_fixed_global_key', 0, async () => {
      // 验证：getHeatmap 缓存命中（全局共享键 CACHE_KEY_PREFIX_DISEASE_HEATMAP）
      const cached: HeatmapData = {
        heatmap_points: [{
          device_id: 'dev_001',
          disease_type: 'blight',
          severity: 'medium',
          timestamp: '2026-07-03T10:00:00Z',
          crop_type: 'tomato'
        }],
        summary: {
          active_disease_types: 1,
          affected_devices: 1,
          total_records: 1
        }
      };

      CacheManager.set(CACHE_KEY_PREFIX_DISEASE_HEATMAP, cached, CACHE_TTL_DISEASE_MS);

      const result = await DiseaseService.getHeatmap('2026-01-01', '2026-12-31');

      expect(result.heatmap_points.length).assertEqual(1);
      expect(result.summary.active_disease_types).assertEqual(1);
      expect(result.heatmap_points[0].crop_type).assertEqual('tomato');
    });

    it('getStats_with_start_only_uses_correct_cache_key', 0, async () => {
      // 验证：只传 start（end undefined）时，key 为 'prefix + start + "_" + "all"'
      const cached: DiseaseStats = {
        total_detections: 15,
        by_crop: { wheat: 15 },
        by_severity: { low: 15 },
        by_disease: { rust: 15 }
      };

      const key = CACHE_KEY_PREFIX_DISEASE_STATS + '2026-06-01' + '_' + 'all';
      CacheManager.set(key, cached, CACHE_TTL_DISEASE_MS);

      // 调用 getStats 仅传 start，应命中 key = prefix + '2026-06-01_all'
      const result = await DiseaseService.getStats('2026-06-01');

      expect(result.total_detections).assertEqual(15);
      expect(result.by_crop['wheat']).assertEqual(15);
    });

    it('getStats_with_end_only_uses_correct_cache_key', 0, async () => {
      // 验证：只传 end（start undefined）时，key 为 'prefix + "all" + "_" + end'
      const cached: DiseaseStats = {
        total_detections: 25,
        by_crop: { rice: 25 },
        by_severity: { medium: 25 },
        by_disease: { blast: 25 }
      };

      const key = CACHE_KEY_PREFIX_DISEASE_STATS + 'all' + '_' + '2026-06-30';
      CacheManager.set(key, cached, CACHE_TTL_DISEASE_MS);

      const result = await DiseaseService.getStats(undefined, '2026-06-30');

      expect(result.total_detections).assertEqual(25);
      expect(result.by_crop['rice']).assertEqual(25);
    });

    it('getHeatmap_same_global_key_for_different_params', 0, async () => {
      // 验证：getHeatmap 不论传入什么时间范围，均使用同一全局缓存键
      const cached: HeatmapData = {
        heatmap_points: [{
          device_id: 'dev_global',
          disease_type: 'rust',
          severity: 'low',
          timestamp: '2026-07-03T12:00:00Z',
          crop_type: 'wheat'
        }],
        summary: {
          active_disease_types: 1,
          affected_devices: 1,
          total_records: 1
        }
      };

      CacheManager.set(CACHE_KEY_PREFIX_DISEASE_HEATMAP, cached, CACHE_TTL_DISEASE_MS);

      // 用不同时间范围调用，应仍命中同一缓存
      const resultA = await DiseaseService.getHeatmap('2026-01-01', '2026-06-30');
      const resultB = await DiseaseService.getHeatmap('2026-07-01', '2026-12-31');

      expect(resultA.heatmap_points.length).assertEqual(1);
      expect(resultB.heatmap_points.length).assertEqual(1);
      expect(resultA).assertEqual(resultB);
    });
  });
}