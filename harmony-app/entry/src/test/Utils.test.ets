import { describe, it, expect } from '@ohos/hypium';
import {
  formatTimestamp,
  parseAlarmFlag,
  sleep,
  buildQueryString,
  isNetworkError,
  nowMs
} from '../main/ets/common/utils';

/**
 * utils.ets 单元测试。
 * 覆盖 formatTimestamp, parseAlarmFlag, sleep, buildQueryString, isNetworkError, nowMs
 */
export default function utilsTest() {
  describe('UtilsTests', () => {

    it('formatTimestamp_formats_valid_iso_strings', 0, () => {
      // 验证正常格式化 ISO 时间
      const formatted = formatTimestamp('2026-07-03T10:15:30.000Z');
      // 由于本地时间可能有时区差异，这里匹配核心的模式，或者验证它可以被解析成有效的格式
      expect(formatted.length === 19).assertTrue(); // YYYY-MM-DD HH:mm:ss 的长度是 19
      expect(formatted.indexOf('-')).assertEqual(4);
      expect(formatted.lastIndexOf(':')).assertEqual(16);
    });

    it('formatTimestamp_returns_original_string_on_invalid_input', 0, () => {
      // 验证解析失败时原样返回
      const invalid = 'not-a-date-string';
      const result = formatTimestamp(invalid);
      expect(result).assertEqual(invalid);
    });

    it('parseAlarmFlag_correctly_parses_individual_flags', 0, () => {
      // 验证单个报警标志位的解析
      expect(parseAlarmFlag(0x01).indexOf('高温') !== -1).assertTrue();
      expect(parseAlarmFlag(0x02).indexOf('低温') !== -1).assertTrue();
      expect(parseAlarmFlag(0x04).indexOf('高湿') !== -1).assertTrue();
      expect(parseAlarmFlag(0x08).indexOf('低湿') !== -1).assertTrue();
      expect(parseAlarmFlag(0x10).indexOf('低光照') !== -1).assertTrue();
      expect(parseAlarmFlag(0x20).indexOf('高CO2') !== -1).assertTrue();
      expect(parseAlarmFlag(0x40).indexOf('低氮') !== -1).assertTrue();
      expect(parseAlarmFlag(0x80).indexOf('低磷') !== -1).assertTrue();
    });

    it('parseAlarmFlag_correctly_parses_combined_flags', 0, () => {
      // 验证组合报警标志位的解析
      const combined = parseAlarmFlag(0x01 | 0x04 | 0x20); // 高温 + 高湿 + 高CO2
      expect(combined.length).assertEqual(3);
      expect(combined.indexOf('高温') !== -1).assertTrue();
      expect(combined.indexOf('高湿') !== -1).assertTrue();
      expect(combined.indexOf('高CO2') !== -1).assertTrue();
    });

    it('parseAlarmFlag_returns_empty_array_for_zero_or_no_match', 0, () => {
      // 验证 0 或不匹配标志位返回空数组
      expect(parseAlarmFlag(0).length).assertEqual(0);
      expect(parseAlarmFlag(0x100).length).assertEqual(0); // 溢出位不匹配
    });

    it('sleep_resolves_after_delay', 0, async () => {
      // 验证 sleep 执行延迟
      const start = nowMs();
      await sleep(50);
      const duration = nowMs() - start;
      expect(duration >= 40).assertTrue(); // 考虑到调度可能提前/滞后，设 40ms 为安全阈值
    });

    it('buildQueryString_converts_objects_correctly', 0, () => {
      // 验证查询参数对象转换
      const params: Record<string, string | number | undefined> = {
        'device_id': 'dev_abc',
        'page': 2,
        'crop_type': undefined
      };
      const query = buildQueryString(params);
      expect(query).assertEqual('?device_id=dev_abc&page=2');
    });

    it('buildQueryString_returns_empty_string_for_empty_or_all_undefined_objects', 0, () => {
      // 验证空对象或全为 undefined 时返回空字符串
      const emptyParams: Record<string, string | number | undefined> = {};
      expect(buildQueryString(emptyParams)).assertEqual('');
      
      const allUndefined: Record<string, string | number | undefined> = {
        'start': undefined,
        'end': undefined
      };
      expect(buildQueryString(allUndefined)).assertEqual('');
    });

    it('isNetworkError_correctly_identifies_network_errors', 0, () => {
      // 验证网络错误的判断
      expect(isNetworkError(null)).assertFalse();
      expect(isNetworkError(undefined)).assertFalse();
      
      const noCodeError = new Error('some error');
      expect(isNetworkError(noCodeError)).assertFalse();

      const validNetworkError: Record<string, Object> = {
        'code': 408,
        'message': 'Timeout'
      };
      expect(isNetworkError(validNetworkError)).assertTrue();
    });

    it('nowMs_returns_valid_timestamp', 0, () => {
      // 验证 nowMs 返回值
      const ts = nowMs();
      expect(typeof ts === 'number').assertTrue();
      expect(ts > 0).assertTrue();
    });

  });
}
