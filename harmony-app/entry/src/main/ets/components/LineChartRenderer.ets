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
  private context: CanvasRenderingContext2D | null = null;

  build() {
    Canvas(this.context)
      .width(this.canvasWidth)
      .height(this.canvasHeight)
      .onReady(() => {
        if (this.context !== null) {
          this.drawChart(this.context);
        }
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

    // 2. 绘制 X 轴（底部水平线）
    ctx.beginPath();
    ctx.moveTo(0, height - 1);
    ctx.lineTo(width, height - 1);
    ctx.stroke();

    // 3. 绘制 Y 轴（左侧垂直线）
    ctx.beginPath();
    ctx.moveTo(0, 0);
    ctx.lineTo(0, height);
    ctx.stroke();

    // 4. 归一化数据
    const min: number = Math.min(...data);
    const max: number = Math.max(...data);
    const range: number = max - min || 1;

    // 5. 折线段绘制
    ctx.beginPath();
    const stepX: number = data.length > 1 ? width / (data.length - 1) : width;
    for (let i = 0; i < data.length; i++) {
      const x: number = i * stepX;
      const y: number = height - ((data[i] - min) / range) * height;
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