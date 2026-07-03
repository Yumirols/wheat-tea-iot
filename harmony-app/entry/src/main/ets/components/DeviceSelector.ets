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

import { AppStorage } from '@kit.ArkUI';
import { DeviceInfo } from '../common/models';

@Component
struct DeviceSelector {
  @Prop devices: DeviceInfo[];
  @State selectedIndex: number = 0;

  aboutToAppear(): void {
    // 初始化 AppStorage 键（已存在则保留）
    AppStorage.setOrCreate('selectedDeviceId', '');
    // 读取持久值并按 device_id 匹配索引同步 selectedIndex
    const stored: string | undefined = AppStorage.get<string>('selectedDeviceId');
    if (stored !== undefined && stored !== '') {
      const idx: number = this.devices.findIndex((d: DeviceInfo): boolean => d.device_id === stored);
      if (idx >= 0) {
        this.selectedIndex = idx;
      }
    }
  }

  build() {
    Select({
      options: this.devices.map((d: DeviceInfo): SelectOption => { return { value: d.device_id }; }),
      selected: this.selectedIndex,
      onSelect: (index: number, value: string): void => {
        this.selectedIndex = index;
        AppStorage.set('selectedDeviceId', value);
      }
    });
  }
}

export { DeviceSelector };