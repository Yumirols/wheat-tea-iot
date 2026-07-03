/**
 * 历史趋势图表容器。
 *
 * 委托给具体渲染器：
 * - `chartType === 'line'` → `LineChartRenderer`
 * - `chartType === 'bar'`  → `BarChartRenderer`
 *
 * **v1.0 限制**：Canvas 不支持响应式重绘。父组件切换设备时通过
 * `<ChartView key={'chart-' + chartRebuildKey} ... />` 强制重建实例触发重绘。
 *
 * Props：
 * - `chartType: 'line' | 'bar' = 'line'` —— 必填（带默认值）
 * - `dataPoints: number[]` —— 必填，Y 轴数据点数组
 * - `width: number = 360` —— 容器宽度（默认 360px）
 * - `height: number = 200` —— 容器高度（默认 200px）
 */

import { LineChartRenderer } from './LineChartRenderer';
import { BarChartRenderer } from './BarChartRenderer';

@Component
struct ChartView {
  @Prop chartType: 'line' | 'bar' = 'line';
  @Prop dataPoints: number[];
  @Prop width: number = 360;
  @Prop height: number = 200;

  build() {
    if (this.chartType === 'line') {
      LineChartRenderer({
        data: this.dataPoints,
        width: this.width,
        height: this.height
      });
    } else {
      BarChartRenderer({
        data: this.dataPoints,
        width: this.width,
        height: this.height
      });
    }
  }
}

export { ChartView };