/**
 * 柱状图渲染器。
 *
 * **v1.0 占位实现**：仅在 `<Canvas onReady>` 回调中调用
 * `ctx.fillText('BarChart v1.0 placeholder', 10, height / 2)` 渲染占位文字，
 * 不绘制矩形柱。
 *
 * Props：
 * - `data: number[]` —— 必填，柱高数据（占位实现中不消费）
 * - `width: number = 360` —— 画布宽度
 * - `height: number = 200` —— 画布高度
 */

@Component
struct BarChartRenderer {
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
          this.drawBars(this.context);
        }
        this.isReady = true;
      });
  }

  /**
   * 占位绘制：在画布中部渲染占位文字。
   * @param ctx 画布上下文
   */
  private drawBars(ctx: CanvasRenderingContext2D): void {
    const height: number = this.canvasHeight;
    ctx.clearRect(0, 0, this.canvasWidth, height);
    ctx.font = '14px sans-serif';
    ctx.fillText('BarChart v1.0 placeholder', 10, height / 2);
  }
}

export { BarChartRenderer };