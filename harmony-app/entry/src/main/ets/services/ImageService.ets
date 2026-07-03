/**
 * 图像服务。
 *
 * 提供两类能力：
 * - `uploadImage(context, filePath, diseaseRecordId?, deviceId?)`：图片上传（委托 `api.uploadFile`）
 * - `getImagePixelMap(path)`：获取图片二进制（`HttpClient.getRaw`）
 *
 * 上传实现说明：
 * - 构造 `header = { [HEADER_API_KEY]: HEADER_KEY }`（`HEADER_KEY` 来自 `HttpClient.HEADER_KEY`）
 * - 构造 `data: Record<string, string>`，按 `diseaseRecordId` / `deviceId` 是否提供决定字段
 * - `url = BASE_URL + '/image/upload'`（`BASE_URL` 来自 `HttpClient.BASE_URL`）
 * - 当前 R1 `api.uploadFile` 为占位实现（返回 `code: 0, data: null`），透传占位结果
 *
 * 像素图下载：
 * - 调用 `HttpClient.getRaw('/image/' + path)`（内部已注入 `X-Api-Key` + 重试 3 次）
 * - 返回 `ArrayBuffer`，**不**做解码（由调用方 `ImageViewer` 等组件负责 `createPixelMap`）
 * - **不**缓存（`ArrayBuffer` 体积大）
 *
 * 缓存：本服务**不**写入 `CacheManager`（上传结果不可重用；二进制内容由业务方按需缓存）
 */

import { common } from '@kit.AbilityKit';
import { ImageUploadResult, ApiResponse } from '../common/models';
import { HEADER_API_KEY } from '../common/constants';
import { uploadFile as apiUploadFile } from '../common/api';
import { BASE_URL, HEADER_KEY, getRaw as httpGetRaw } from './HttpClient';

/**
 * 上传图片。
 *
 * - 委托 `api.uploadFile()`，由本服务注入 `X-Api-Key` 头
 * - 成功（`code === 0 && data !== null`）返回 `data`
 * - 业务失败抛 `Error(resp.message)`
 *
 * @param context `UIAbilityContext`（来自 `@kit.AbilityKit`）
 * @param filePath 文件相对路径（拼装为 `internal://cache/<filePath>`）
 * @param diseaseRecordId 可选关联的病虫害记录 ID
 * @param deviceId 可选关联的设备 ID
 * @returns 上传结果 `ImageUploadResult`
 * @throws `Error(resp.message)`（业务失败）/ `Error('Upload failed')` / 网络异常
 */
async function uploadImage(
  context: common.UIAbilityContext,
  filePath: string,
  diseaseRecordId?: number,
  deviceId?: string
): Promise<ImageUploadResult> {
  const header: Record<string, string> = {};
  header[HEADER_API_KEY] = HEADER_KEY;

  const data: Record<string, string> = {};
  if (diseaseRecordId !== undefined) {
    data['disease_record_id'] = String(diseaseRecordId);
  }
  if (deviceId !== undefined) {
    data['device_id'] = deviceId;
  }

  const url: string = BASE_URL + '/image/upload';

  const resp: ApiResponse<ImageUploadResult> = await apiUploadFile(context, url, filePath, header, data);

  if (resp.code !== 0 || resp.data === null) {
    throw new Error(resp.message || 'Image upload error');
  }

  return resp.data;
}

/**
 * 获取图片二进制数据。
 *
 * - 内部 `GET /image/<path>`（`HttpClient.getRaw` 自动注入 `X-Api-Key` + 重试 3 次）
 * - **不**做解码；调用方（`ImageViewer` 组件）负责 `image.createImageSource(...).createPixelMap(...)`
 *
 * @param path 图片 ID（如 `img_20260703_061500_021`），拼为 `/image/<path>`
 * @returns 图片二进制 `ArrayBuffer`
 * @throws 网络异常（来自 `HttpClient.getRaw`）
 */
async function getImagePixelMap(path: string): Promise<ArrayBuffer> {
  return httpGetRaw('/image/' + path);
}

export const ImageService = {
  uploadImage: uploadImage,
  getImagePixelMap: getImagePixelMap
};
