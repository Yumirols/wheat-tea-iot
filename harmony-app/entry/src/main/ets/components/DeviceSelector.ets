/**
 * 设备下拉选择器。
 *
 * - 通过 ArkUI 内建 `<Select>` 渲染设备列表（`value` 来自 `DeviceInfo.device_id`）
 * - **单一写入源**：`aboutToAppear` 中 `AppStorage.setOrCreate('selectedDeviceId', '')`
 *   初始化键（已存在则不覆盖）；同时读取持久值，按 `device_id` 匹配索引后同步 `selectedIndex`
 *   消除二次启动 UI 与持久化撕裂
 * - 用户切换时 `this.selectedIndex = index` + `AppStorage.set('selectedDeviceId', value)`
 * - 父 Page 层契约：通过 `@StorageLink('selectedDeviceId') selectedDeviceId: string`
 *   监听变化触发 Service 重新拉取
 *
 * 注意：本组件**不**调用 `DeviceService`；`devices` 由父组件传入。
 *
 * Props：
 * - `devices: DeviceInfo[]` —— 必填，设备列表
 */

import { DeviceInfo } from '../common/models';

@Component
struct DeviceSelector {
  @Prop @Watch('syncSelectedIndex') devices: DeviceInfo[];
  @StorageLink('selectedDeviceId') @Watch('syncSelectedIndex') selectedDeviceId: string = '';
  @State selectedIndex: number = 0;
  @State selectedDeviceName: string = '';

  aboutToAppear(): void {
    this.syncSelectedIndex();
  }

  private syncSelectedIndex(): void {
    if (this.devices && this.devices.length > 0) {
      if (this.selectedDeviceId !== '') {
        const idx: number = this.devices.findIndex((d: DeviceInfo): boolean => d.device_id === this.selectedDeviceId);
        if (idx >= 0) {
          this.selectedIndex = idx;
          this.selectedDeviceName = this.devices[idx].device_name || this.devices[idx].device_id || '';
          return;
        }
      }
      this.selectedIndex = 0;
      this.selectedDeviceName = this.devices[0].device_name || this.devices[0].device_id || '';
      this.selectedDeviceId = this.devices[0].device_id;
    } else {
      this.selectedDeviceName = '';
    }
  }

  private truncateDeviceName(name: string): string {
    if (!name) {
      return '';
    }
    const maxLen = 16;
    if (name.length <= maxLen) {
      return name;
    }

    // Special handling for '<hex_id>_<name>' pattern
    const underscoreIndex = name.indexOf('_');
    if (underscoreIndex > 0 && name.length - underscoreIndex > 3) {
      const prefix = name.substring(0, Math.min(6, underscoreIndex));
      const suffix = name.substring(underscoreIndex); // includes the underscore
      const result = prefix + '...' + suffix;
      if (result.length <= maxLen + 4) {
        return result;
      }
    }

    // Fallback: simple tail truncation
    return name.substring(0, maxLen - 3) + '...';
  }

  build() {
    Select(this.devices.map((d: DeviceInfo): SelectOption => { return { value: this.truncateDeviceName(d.device_name || d.device_id || '') }; }))
      .selected(this.selectedIndex)
      .value(this.devices.length > 0 ? this.truncateDeviceName(this.devices[this.selectedIndex]?.device_name || this.devices[this.selectedIndex]?.device_id || '') : '')
      .font({ size: 14, weight: FontWeight.Medium })
      .fontColor('#1e2a38')
      .selectedOptionFont({ size: 14 })
      .optionFont({ size: 14 })
      .width(140)
      .height(36)
      .onSelect((index: number, value: string): void => {
        if (index >= 0 && index < this.devices.length) {
          this.selectedIndex = index;
          this.selectedDeviceName = this.devices[index].device_name || this.devices[index].device_id || '';
          this.selectedDeviceId = this.devices[index].device_id;
        }
      });
  }
}

export { DeviceSelector };