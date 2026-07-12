import { describe, beforeEach, it, expect } from '@ohos/hypium';
import { CacheManager } from '../main/ets/common/CacheManager';
import { sleep } from '../main/ets/common/utils';

/**
 * CacheManager.ets 单元测试。
 * 覆盖 set, get, invalidate, clear
 */
export default function cacheManagerTest() {
  describe('CacheManagerTests', () => {
    beforeEach(() => {
      CacheManager.clear();
    });

    it('set_and_get_retrieves_valid_unexpired_items', 0, () => {
      const data: Record<string, string> = { 'foo': 'bar' };
      CacheManager.set('test_key', data, 1000);
      
      const retrieved = CacheManager.get<Record<string, string>>('test_key');
      expect(retrieved !== null).assertTrue();
      expect(retrieved!['foo']).assertEqual('bar');
    });

    it('get_returns_null_for_non_existent_key', 0, () => {
      const retrieved = CacheManager.get<Object>('non_existent');
      expect(retrieved === null).assertTrue();
    });

    it('get_returns_null_and_removes_expired_items', 0, async () => {
      const data = 'expired_data';
      // 设置极短的 TTL (10ms)
      CacheManager.set('expire_key', data, 10);
      
      // 等待 20ms 使其过期
      await sleep(20);
      
      const retrieved = CacheManager.get<string>('expire_key');
      expect(retrieved === null).assertTrue();
      
      // 验证已被删除（不再在 store 中，直接用 get 应依旧为 null）
      const retrievedAgain = CacheManager.get<string>('expire_key');
      expect(retrievedAgain === null).assertTrue();
    });

    it('invalidate_manually_removes_specific_items', 0, () => {
      CacheManager.set('key_to_delete', 'some_val', 5000);
      
      const before = CacheManager.get<string>('key_to_delete');
      expect(before).assertEqual('some_val');
      
      CacheManager.invalidate('key_to_delete');
      
      const after = CacheManager.get<string>('key_to_delete');
      expect(after === null).assertTrue();
    });

    it('clear_wipes_out_all_cached_items', 0, () => {
      CacheManager.set('k1', 'v1', 5000);
      CacheManager.set('k2', 'v2', 5000);
      
      CacheManager.clear();
      
      expect(CacheManager.get<string>('k1') === null).assertTrue();
      expect(CacheManager.get<string>('k2') === null).assertTrue();
    });

  });
}
