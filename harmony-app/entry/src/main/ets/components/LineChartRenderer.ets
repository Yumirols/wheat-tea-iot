/**
 * 折线图渲染器。
 *
 * **v1.0 一次性绘制**：在 `<Canvas onReady>` 回调中获取 `CanvasRenderingContext2D`
 * 并完整绘制；数据变更不触发自动重绘（父组件通过 `key` 强制重建实例）。
 *
 * 绘制流程：
 * 0. 空数组防御（防止 `Math.min(...[])` 返回 `Infinity`）
 * 1. 清空画布
 * 2. 绘制 X 轴（底部水平线）
 * 3. 绘制 Y 轴（左侧垂直线）
 * 4. 归一化数据
 * 5. 折线段绘制
 *
 * v1.0 限制：
 * - 单 Y 轴单折线
 * - 无触摸交互
 * - 无动画过渡
 * - 静态绘制
 *
 * Props：
 * - `data: number[]` —— 必填，Y 轴数据点
 * - `width: number = 360` —— 画布宽度
 * - `height: number = 200` —— 画布高度
 */

@Component
struct LineChartRenderer {
  @Prop data: number[];
  @Prop canvasWidth: number = 360;
  @Prop canvasHeight: number = 200;
  @State private isReady: boolean = false;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  build() {
    Canvas(this.context)
      .width(this.canvasWidth)
      .height(this.canvasHeight)
      .onReady(() => {
        this.drawChart(this.context);
        this.isReady = true;
      });
  }

  /**
   * 一次性绘制折线图。空数组直接返回（避免 `Math.min(...[])` 返回 `Infinity`）。
   * @param ctx 画布上下文
   */
  private drawChart(ctx: CanvasRenderingContext2D): void {
    const data: number[] = this.data;
    const width: number = this.canvasWidth;
    const height: number = this.canvasHeight;

    // 0. 空数组防御
    if (data.length === 0) {
      return;
    }

    // 1. 清空画布
    ctx.clearRect(0, 0, width, height);

    // 2. 绘制 X 轴和 Y 轴（加 10px 边距防切边）
    ctx.strokeStyle = '#cbd5e1'; // 浅灰色轴线
    ctx.lineWidth = 1;

    ctx.beginPath();
    ctx.moveTo(10, height - 10);
    ctx.lineTo(width - 10, height - 10);
    ctx.stroke();

    ctx.beginPath();
    ctx.moveTo(10, 10);
    ctx.lineTo(10, height - 10);
    ctx.stroke();

    // 4. 归一化数据
    const min: number = Math.min(...data);
    const max: number = Math.max(...data);
    const range: number = max - min || 1;

    // 5. 折线段绘制
    ctx.beginPath();
    ctx.strokeStyle = '#00b894'; // 翡翠绿折线配色
    ctx.lineWidth = 2;

    const chartWidth = width - 20;
    const chartHeight = height - 20;
    const stepX: number = data.length > 1 ? chartWidth / (data.length - 1) : chartWidth;

    for (let i = 0; i < data.length; i++) {
      const x: number = 10 + i * stepX;
      const y: number = (height - 10) - ((data[i] - min) / range) * chartHeight;
      if (i === 0) {
        ctx.moveTo(x, y);
      } else {
        ctx.lineTo(x, y);
      }
    }
    ctx.stroke();
  }
}

export { LineChartRenderer };