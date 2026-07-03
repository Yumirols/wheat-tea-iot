/**
 * 控制按钮。
 *
 * 通过 `@Link` 双向绑定父组件状态，提供乐观 UI + 失败回滚能力。
 *
 * 行为：
 * 1. 用户点击 → `previousState = this.isOn` + `this.isOn = !this.isOn`（乐观翻转）
 * 2. 置 `isPending = true`（按钮 disabled）
 * 3. 异步调用 `onToggle(target)`
 * 4. 成功 → `isPending = false`
 * 5. 失败 → `this.isOn = previousState` 回滚 + `console.error` + `isPending = false`
 *
 * 父组件约束：
 * - `isOn` 必须用 `@State isOn: boolean` 持有（`@Link` 仅支持双向同步 `@State`）
 * - 父组件用法示例：
 *   ```typescript
 *   @State private isSprayOn: boolean = false;
 *   ControlButton({ isOn: $isSprayOn, label: '喷淋', onToggle: this.handleSpray });
 *   ```
 *
 * Props：
 * - `@Link isOn: boolean` —— 必填，双向绑定父组件状态
 * - `label: string` —— 必填，按钮标签（如"喷淋"）
 * - `onToggle: (target: boolean) => Promise<void>` —— 必填，切换回调
 */

@Component
struct ControlButton {
  @Link isOn: boolean;
  @Prop label: string;
  @Prop onToggle: (target: boolean) => Promise<void> = async (_: boolean): Promise<void> => { /* default no-op */ };
  @State private previousState: boolean = false;
  @State private isPending: boolean = false;

  build() {
    Button(this.isOn ? '已开启' : '已关闭')
      .onClick(() => {
        this.handleToggle();
      })
      .enabled(!this.isPending);
  }

  /**
   * 切换处理：乐观 UI 翻转 + 异步执行 + 失败回滚。
   */
  private async handleToggle(): Promise<void> {
    const target: boolean = !this.isOn;
    this.previousState = this.isOn;
    this.isOn = target;
    this.isPending = true;
    try {
      await this.onToggle(target);
    } catch (err: unknown) {
      this.isOn = this.previousState;
      console.error('ControlButton toggle error', JSON.stringify(err));
    } finally {
      this.isPending = false;
    }
  }
}

export { ControlButton };