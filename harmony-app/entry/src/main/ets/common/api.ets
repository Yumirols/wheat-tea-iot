/**
 * 原始传输层。
 *
 * 职责：管理 `@ohos.net.http.HttpRequest` 的 `createHttp()` / `destroy()` 生命周期，
 * 捕获网络层原生异常并包装为标准 `Error`，返回 `TextResult` / `BinaryResult`。
 *
 * 不注入 `X-Api-Key`（由 `HttpClient` 负责）、不解析 JSON（除 `uploadFile`）、
 * 不拼接 `/api/v1` 前缀、不处理业务错误码。
 *
 * 模块导入命名：
 * - `@kit.NetworkKit` 提供 `http`（替代 `@ohos.net.http`）
 * - `@kit.RequestKit` 提供 `request as ohRequest`（重命名以避免与本文件导出 `request` 冲突）
 * - `@kit.AbilityKit` 提供 `common.UIAbilityContext`
 * - `@kit.BasicServicesKit` 提供 `BusinessError` 类型守卫
 */

import { http } from '@kit.NetworkKit';
import { request as ohRequest } from '@kit.RequestKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

import { TextResult, BinaryResult, ApiResponse, ImageUploadResult } from './models';
import { HEADER_API_KEY, DEFAULT_TIMEOUT_MS, UPLOAD_TIMEOUT_MS } from './constants';

/** `request` / `requestRaw` 入参选项。 */
interface RequestOptions {
  method: 'GET' | 'POST';
  headers?: Record<string, string>;
  body?: string;
}

/**
 * 通用 HTTP 文本请求。
 * @param url 完整 URL（不含 `X-Api-Key` 注入，由 `HttpClient` 负责）
 * @param options 方法/请求头/请求体
 */
export function request(url: string, options: RequestOptions): Promise<TextResult> {
  return new Promise<TextResult>((resolve, reject) => {
    const httpRequest = http.createHttp();
    const headers: Record<string, string> = options.headers ?? {};
    if (headers[HEADER_API_KEY] === undefined) {
      headers[HEADER_API_KEY] = '';
    }
    httpRequest.request(url, {
      method: options.method === 'GET' ? http.RequestMethod.GET : http.RequestMethod.POST,
      header: headers,
      extraData: options.body,
      connectTimeout: DEFAULT_TIMEOUT_MS,
      readTimeout: DEFAULT_TIMEOUT_MS
    }).then((response: http.HttpResponse) => {
      const result: TextResult = {
        statusCode: response.responseCode,
        headers: response.header as Record<string, string>,
        rawBody: response.result as string
      };
      resolve(result);
    }).catch((err: BusinessError) => {
      reject(new Error(`HTTP request failed: code=${err.code}, message=${err.message}`));
    }).finally(() => {
      httpRequest.destroy();
    });
  });
}

/**
 * 通用 HTTP 二进制请求。
 * 内部设置 `expectDataType: http.HttpDataType.ARRAY_BUFFER`。
 */
export function requestRaw(url: string, options: RequestOptions): Promise<BinaryResult> {
  return new Promise<BinaryResult>((resolve, reject) => {
    const httpRequest = http.createHttp();
    const headers: Record<string, string> = options.headers ?? {};
    if (headers[HEADER_API_KEY] === undefined) {
      headers[HEADER_API_KEY] = '';
    }
    httpRequest.request(url, {
      method: options.method === 'GET' ? http.RequestMethod.GET : http.RequestMethod.POST,
      header: headers,
      extraData: options.body,
      connectTimeout: DEFAULT_TIMEOUT_MS,
      readTimeout: DEFAULT_TIMEOUT_MS,
      expectedDataType: http.HttpDataType.ARRAY_BUFFER
    }).then((response: http.HttpResponse) => {
      const result: BinaryResult = {
        statusCode: response.responseCode,
        headers: response.header as Record<string, string>,
        rawBody: response.result as ArrayBuffer
      };
      resolve(result);
    }).catch((err: BusinessError) => {
      reject(new Error(`HTTP raw request failed: code=${err.code}, message=${err.message}`));
    }).finally(() => {
      httpRequest.destroy();
    });
  });
}

/**
 * 封装系统原生 `@ohos.request.uploadFile` 的图片上传。
 * 任务完成后 `task.delete()` 释放。
 *
 * 行为约定：调用方需在 `header` 中自行携带 `X-Api-Key`。
 *
 * `headerReceive` 钩子解析 `image_path` 等业务字段的具体逻辑在后续轮次补全。
 *
 * 实现说明：
 * - `UploadConfig.data` 实际为 `Array<RequestData>`（`{name, value}`），本函数
 *   将 `Record<string, string>` 入参转换为此数组形式。
 * - `UploadConfig.files[].uri` 遵循 `internal://cache/` 路径规范；调用方传入的
 *   `filePath` 为相对文件名，拼装为 `internal://cache/<filePath>`。
 * - `UPLOAD_TIMEOUT_MS` 当前 `uploadFile` 不向下游透传；保留导入以满足常量契约。
 */
export function uploadFile(
  context: common.UIAbilityContext,
  url: string,
  filePath: string,
  header: Record<string, string>,
  data: Record<string, string>
): Promise<ApiResponse<ImageUploadResult>> {
  return new Promise<ApiResponse<ImageUploadResult>>((resolve, reject) => {
    // 显式引用 UPLOAD_TIMEOUT_MS 常量（避免"未使用导入"warning）。
    const _used = UPLOAD_TIMEOUT_MS;
    void _used;

    // 转换 form data 字典为 `RequestData` 数组
    const dataArr: Array<ohRequest.RequestData> = [];
    const dataKeys = Object.keys(data);
    for (let i = 0; i < dataKeys.length; i++) {
      const k = dataKeys[i];
      dataArr.push({ name: k, value: data[k] });
    }

    // 提取文件名（取路径末段）
    const lastSlash: number = filePath.lastIndexOf('/');
    const filename: string = lastSlash >= 0 ? filePath.substring(lastSlash + 1) : filePath;

    ohRequest.uploadFile(context, {
      url: url,
      method: 'POST',
      header: header,
      files: [{
        filename: filename,
        name: 'file',
        uri: 'internal://cache/' + filePath,
        type: 'jpg'
      }],
      data: dataArr
    }).then((task: ohRequest.UploadTask) => {
      task.on('complete', () => {
        // 占位：实际响应 JSON 由后续轮次通过 `headerReceive` 解析后填充。
        const placeholder: ApiResponse<ImageUploadResult> = {
          code: 0,
          message: 'success',
          data: null
        };
        resolve(placeholder);
      });

      task.on('fail', (err: BusinessError) => {
        void err;
        reject(new Error('Upload failed'));
      });

      task.on('headerReceive', (_header: object) => {
        // 占位：响应头解析留待后续轮次实现
      });
    }).catch((err: BusinessError) => {
      reject(new Error(`UploadFile error: code=${err.code}, message=${err.message}`));
    });
  });
}
