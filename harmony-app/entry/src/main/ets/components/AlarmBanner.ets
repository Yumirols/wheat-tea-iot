/**
 * 告警横幅。
 *
 * 顶部告警条带，三色背景 + 右上角关闭按钮 + 整体点击回调。
 * - `message === ''` 时跳过整个 `build()`（父组件可传空字符串隐藏）
 * - `severity` 三色 + 灰色兜底
 *
 * Props：
 * - `message: string` —— 必填，告警文本；空字符串时不渲染
 * - `severity: string` —— 必填，与 `SeverityBadge.severity` 同语义
 * - `onClose?: () => void` —— 可选，关闭按钮点击回调
 * - `onTap?: () => void` —— 可选，横幅整体点击回调
 */

@Component
struct AlarmBanner {
  @Prop message: string;
  @Prop severity: string;
  onClose?: () => void;
  onTap?: () => void;

  build() {
    Row() {
      if (this.message !== '') {
        Text(this.message)
          .layoutWeight(1)
          .fontSize(14)
        Text('×')
          .fontSize(20)
          .fontColor(Color.Gray)
          .onClick(() => {
            this.onClose?.();
          })
      }
    }
    .width(this.message !== '' ? '100%' : 0)
    .height(this.message !== '' ? undefined : 0)
    .padding(this.message !== '' ? 12 : 0)
    .backgroundColor(
      this.severity === 'mild' ? '#E8F5E9' :
      this.severity === 'moderate' ? '#FFF3E0' :
      this.severity === 'severe' ? '#FFEBEE' :
      '#F5F5F5'
    )
    .onClick(() => {
      this.onTap?.();
    })
  }
}

export { AlarmBanner };