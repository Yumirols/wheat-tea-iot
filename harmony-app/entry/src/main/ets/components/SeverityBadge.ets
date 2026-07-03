/**
 * 严重度文字徽标。
 *
 * 根据英文 `severity` 字符串映射为不同颜色 + 中文标签的徽标：
 * - `'mild'` → 绿色 `#4CAF50` + "轻度"
 * - `'moderate'` → 橙色 `#FF9800` + "中度"
 * - `'severe'` → 红色 `#F44336` + "重度"
 * - 其它字符串值（含中文"轻度/中度/重度"或任意未知值）→ 灰色 `#9E9E9E` + 原 severity 字符串
 *
 * Props：
 * - `severity: string` —— 必填，与 `DiseaseRecord.severity: string` 对齐
 */

@Component
struct SeverityBadge {
  @Prop severity: string;

  build() {
    Row() {
      if (this.severity === 'mild') {
        Text('轻度')
          .fontColor(Color.White)
          .fontSize(12)
      } else if (this.severity === 'moderate') {
        Text('中度')
          .fontColor(Color.White)
          .fontSize(12)
      } else if (this.severity === 'severe') {
        Text('重度')
          .fontColor(Color.White)
          .fontSize(12)
      } else {
        Text(this.severity)
          .fontColor(Color.White)
          .fontSize(12)
      }
    }
    .backgroundColor(
      this.severity === 'mild' ? '#4CAF50' :
      this.severity === 'moderate' ? '#FF9800' :
      this.severity === 'severe' ? '#F44336' :
      '#9E9E9E'
    )
    .padding(4)
    .borderRadius(4)
  }
}

export { SeverityBadge };