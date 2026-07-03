/**
 * 图片查看器。
 *
 * 双路径渲染策略：
 * - **主路径**：`<Image src={HttpClient.BASE_URL + imagePath}>` 直连加载
 *   （服务端对 `/images/...` 目录放行免鉴权）
 * - **降级路径**：主路径 `onError` 时切换 → `ImageService.getImagePixelMap(imageId)`
 *   → `ArrayBuffer` → `image.createImageSource(buf).createPixelMap()` → `<Image pixelMap>`
 *
 * 加载中显示 `<Progress>` 居中占位；最终降级路径也失败时显示"图片加载失败"。
 *
 * Props：
 * - `imagePath: string` —— 必填，URL 相对路径（主路径，如 `/images/.../img_xxx.jpg`）
 * - `imageId: string` —— 必填，纯 ID（降级路径，如 `img_20260703_061500_021`）
 */

import { image } from '@kit.ImageKit';
import { ImageService } from '../services/ImageService';
import { BASE_URL } from '../services/HttpClient';

@Component
struct ImageViewer {
  @Prop imagePath: string;
  @Prop imageId: string;
  @State private pixelMap: image.PixelMap | null = null;
  @State private loadStatus: 'idle' | 'loading' | 'loaded' | 'error' = 'idle';

  build() {
    Stack() {
      if (this.loadStatus === 'loading') {
        Progress({ type: ProgressType.Circular });
      } else if (this.loadStatus === 'error') {
        Text('图片加载失败')
          .fontSize(14)
          .fontColor(Color.Gray);
      } else {
        if (this.pixelMap !== null) {
          Image(this.pixelMap);
        } else {
          Image(BASE_URL + this.imagePath)
            .onError((_event?: object): void => {
              this.fallbackToPixelMap();
            });
        }
      }
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center);
  }

  /**
   * 降级到 PixelMap 路径：从 `ImageService` 拉取 ArrayBuffer 后解码。
   */
  private async fallbackToPixelMap(): Promise<void> {
    this.loadStatus = 'loading';
    try {
      const buf: ArrayBuffer = await ImageService.getImagePixelMap(this.imageId);
      const source: image.ImageSource = image.createImageSource(buf);
      const pm: image.PixelMap = await source.createPixelMap();
      this.pixelMap = pm;
      this.loadStatus = 'loaded';
    } catch (err: unknown) {
      this.loadStatus = 'error';
      console.error('ImageViewer fallback error', JSON.stringify(err));
    }
  }
}

export { ImageViewer };