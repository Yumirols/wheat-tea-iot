/**
 * 连接状态指示器。
 *
 * 顶部 4px 细条，纯色背景，宽度自适应屏幕：
 * - `'loading'` → 黄色 `#FFC107`（连接中）
 * - `'online'`  → 绿色 `#4CAF50`（已连接）
 * - `'offline'` → 红色 `#F44336`（离线）
 *
 * 单位约定：
 * - 宽度使用字符串 `'100%'`（响应式自适应屏幕）
 * - 高度使用数字 `4`（vp 单位，固定 4px 细条）
 *
 * Props：
 * - `status: ConnectivityStatus = 'loading'` —— 必填（带默认）
 */

import { ConnectivityStatus } from '../common/models';

@Component
struct ConnectivityIndicator {
  @Prop status: ConnectivityStatus = 'loading';

  build() {
    Row()
      .width('100%')
      .height(4)
      .backgroundColor(
        this.status === 'online' ? '#4CAF50' :
        this.status === 'offline' ? '#F44336' :
        '#FFC107'
      );
  }
}

export { ConnectivityIndicator };