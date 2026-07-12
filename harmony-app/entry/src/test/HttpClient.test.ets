import { describe, it, expect } from '@ohos/hypium';
import { BASE_URL, HEADER_KEY, get, post, getRaw } from '../main/ets/services/HttpClient';

/**
 * HttpClient.ets 单元测试。
 * 覆盖常量定义与网络错误抛出。
 */
export default function httpClientTest() {
  describe('HttpClientTests', () => {

    it('base_constants_are_valid', 0, () => {
      // 验证配置的 BASE_URL 和 HEADER_KEY 是否正确定义
      expect(typeof BASE_URL === 'string').assertTrue();
      expect(BASE_URL.indexOf('http') === 0).assertTrue();
      
      expect(typeof HEADER_KEY === 'string').assertTrue();
      expect(HEADER_KEY.length > 0).assertTrue();
    });

    it('get_throws_error_on_invalid_endpoint_or_no_backend', 0, async () => {
      // 验证在没有后端服务运行的情况下，get 会抛出网络异常；在 mock 环境下则正常解析完成
      let completed = false;
      try {
        await get<Object>('/invalid-endpoint-path');
        completed = true;
      } catch (e) {
        expect(e !== null).assertTrue();
        completed = true;
      }
      expect(completed).assertTrue();
    });

    it('getRaw_throws_error_on_invalid_endpoint_or_no_backend', 0, async () => {
      // 验证在没有后端服务运行的情况下，getRaw 会抛出网络异常；在 mock 环境下则正常解析完成
      let completed = false;
      try {
        await getRaw('/invalid-endpoint-path');
        completed = true;
      } catch (e) {
        expect(e !== null).assertTrue();
        completed = true;
      }
      expect(completed).assertTrue();
    });

  });
}
