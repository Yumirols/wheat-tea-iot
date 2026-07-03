/**
 * 统一加载占位。
 *
 * 三态分支：
 * - `loading` → `<Progress type={ProgressType.Circular}>` + "加载中..."
 * - `error`   → 错误图标 + `errorMessage`（空时降级显示"加载失败，请重试"）+ "重试"按钮
 * - `empty`   → 空图标 + "暂无数据"
 *
 * Props：
 * - `status: 'loading' | 'error' | 'empty'` —— 必填，三态枚举
 * - `errorMessage: string` —— 必填（字符串可为空 `''`）
 *   - **约定**：`status === 'error'` 时应提供非空字符串；为空时降级显示"加载失败，请重试"
 * - `onRetry?: () => void` —— 可选，错误态"重试"按钮回调
 *   - **约定**：`status === 'error'` 时应提供
 */

@Component
struct LoadingState {
  @Prop status: 'loading' | 'error' | 'empty';
  @Prop errorMessage: string;
  @Prop onRetry?: () => void;

  build() {
    Column() {
      if (this.status === 'loading') {
        Progress({ type: ProgressType.Circular })
        Text('加载中...')
          .fontSize(14)
          .fontColor(Color.Gray)
          .margin({ top: 8 })
      } else if (this.status === 'error') {
        Text('⚠')
          .fontSize(32)
          .fontColor(Color.Red)
        Text(this.errorMessage !== '' ? this.errorMessage : '加载失败，请重试')
          .fontSize(14)
          .fontColor(Color.Gray)
          .margin({ top: 8 })
        Button('重试')
          .margin({ top: 12 })
          .onClick(() => {
            this.onRetry?.();
          })
      } else {
        Text('∅')
          .fontSize(32)
          .fontColor(Color.Gray)
        Text('暂无数据')
          .fontSize(14)
          .fontColor(Color.Gray)
          .margin({ top: 8 })
      }
    }
    .width('100%')
    .padding(24)
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
  }
}

export { LoadingState };