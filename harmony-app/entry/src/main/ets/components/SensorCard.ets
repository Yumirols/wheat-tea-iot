/**
 * 传感器参数卡片。
 *
 * 单值展示：参数名 + 大字号数值 + 单位 + 时间戳。
 * - 当 `alarmLabels.length > 0` 时背景切为告警色（浅红 `#FFEBEE`）
 * - `timestamp === ''` 时显示 `'--'`
 *
 * Props：
 * - `label: string` —— 必填，参数名（如"温度"）
 * - `value: number` —— 必填，数值（0 是合法传感器值）
 * - `unit: string` —— 必填，单位后缀（如"℃"）
 * - `timestamp: string` —— 必填，ISO 时间字符串；空时显示 `--`
 * - `alarmLabels: string[] = []` —— 可选，告警标签数组（中文），默认 `[]`
 *   - 由父组件调用 `parseAlarmFlag(snapshot.alarm_flag)` 后传入
 */

import { formatTimestamp } from '../common/utils';

@Component
struct SensorCard {
  @Prop label: string;
  @Prop value: number;
  @Prop unit: string;
  @Prop timestamp: string;
  @Prop alarmLabels: string[] = [];

  build() {
    Column() {
      Text(this.label)
        .fontSize(14)
        .fontColor(Color.Gray)
      Row() {
        Text(String(this.value))
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
        Text(this.unit)
          .fontSize(14)
          .fontColor(Color.Gray)
          .margin({ left: 4 })
      }
      .margin({ top: 4 })
      Text(this.timestamp !== '' ? formatTimestamp(this.timestamp) : '--')
        .fontSize(12)
        .fontColor(Color.Gray)
        .margin({ top: 4 })
    }
    .padding(12)
    .backgroundColor(this.alarmLabels.length > 0 ? '#FFEBEE' : '#FFFFFF')
    .borderRadius(8)
    .alignItems(HorizontalAlign.Start)
  }
}

export { SensorCard };