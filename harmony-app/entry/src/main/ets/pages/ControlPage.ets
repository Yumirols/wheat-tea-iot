import { promptAction } from '@kit.ArkUI';
import { CommandLog, DeviceInfo, ConnectivityStatus } from '../common/models';
import { CommandService } from '../services/CommandService';
import { DeviceService } from '../services/DeviceService';
import { formatTimestamp, sleep } from '../common/utils';
import {
  CMD_LED_ON,
  CMD_LED_OFF,
  CMD_BEEP_ON,
  CMD_BEEP_OFF,
  CMD_SPRAY_ON,
  CMD_SPRAY_OFF,
  CMD_IRRIG_ON,
  CMD_IRRIG_OFF,
  COMMAND_SOURCE_MANUAL_APP
} from '../common/constants';
import { ControlButton } from '../components/ControlButton';
import { ConnectivityIndicator } from '../components/ConnectivityIndicator';
import { LoadingState } from '../components/LoadingState';

@Component
export struct ControlPage {
  @StorageLink('selectedDeviceId') @Watch('onDeviceIdChanged') selectedDeviceId: string = '';
  @State private deviceName: string = '';
  @State private isOnline: boolean = false;
  @State private connectivity: ConnectivityStatus = 'loading';

  // Actuators States
  @State private isLedOn: boolean = false;
  @State private isBeepOn: boolean = false;
  @State private isSprayOn: boolean = false;
  @State private isIrrigOn: boolean = false;

  // Logs States
  @State private logs: CommandLog[] = [];
  @State private isLoadingLogs: boolean = true;
  @State private logsError: string = '';

  private isDestroyed: boolean = false;

  aboutToAppear(): void {
    this.isDestroyed = false;
    this.refreshPageData();
  }

  aboutToDisappear(): void {
    this.isDestroyed = true;
  }

  onDeviceIdChanged(): void {
    if (this.isDestroyed) return;
    this.refreshPageData();
  }

  private async refreshPageData(): Promise<void> {
    if (!this.selectedDeviceId) return;
    
    // 1. Get device details and online status
    const cached = DeviceService.getCachedDevices(this.selectedDeviceId);
    if (cached.length > 0) {
      this.deviceName = cached[0].device_name;
      this.isOnline = cached[0].online;
      this.connectivity = this.isOnline ? 'online' : 'offline';
    } else {
      this.deviceName = this.selectedDeviceId;
      this.connectivity = 'offline';
    }

    // 2. Fetch history and initialize switches from latest successful logs
    this.isLoadingLogs = true;
    this.logsError = '';
    try {
      await this.fetchLogs();
      await this.initSwitchStates();
    } catch (err) {
      if (this.isDestroyed) return;
      this.logsError = err instanceof Error ? err.message : '获取日志失败';
    } finally {
      if (this.isDestroyed) return;
      this.isLoadingLogs = false;
    }
  }

  private async fetchLogs(): Promise<void> {
    if (!this.selectedDeviceId) return;
    const data = await CommandService.getLogs(this.selectedDeviceId, undefined, undefined, undefined, 1, 15);
    if (this.isDestroyed) return;
    this.logs = data.records || [];
  }

  private async initSwitchStates(): Promise<void> {
    // Determine the latest status based on successful commands (result_code == 0)
    let ledSet = false;
    let beepSet = false;
    let spraySet = false;
    let irrigSet = false;

    for (let i = 0; i < this.logs.length; i++) {
      const log = this.logs[i];
      if (log.result_code !== 0) continue;

      if (!ledSet && (log.command === CMD_LED_ON || log.command === CMD_LED_OFF)) {
        this.isLedOn = log.command === CMD_LED_ON;
        ledSet = true;
      }
      if (!beepSet && (log.command === CMD_BEEP_ON || log.command === CMD_BEEP_OFF)) {
        this.isBeepOn = log.command === CMD_BEEP_ON;
        beepSet = true;
      }
      if (!spraySet && (log.command === CMD_SPRAY_ON || log.command === CMD_SPRAY_OFF)) {
        this.isSprayOn = log.command === CMD_SPRAY_ON;
        spraySet = true;
      }
      if (!irrigSet && (log.command === CMD_IRRIG_ON || log.command === CMD_IRRIG_OFF)) {
        this.isIrrigOn = log.command === CMD_IRRIG_ON;
        irrigSet = true;
      }
    }
  }

  private async executeCommand(actuator: string, targetState: boolean): Promise<void> {
    if (!this.selectedDeviceId) {
      throw new Error('No device selected');
    }

    // 1. Check online status in DeviceService.getCachedDevices(deviceId)
    const cached = DeviceService.getCachedDevices(this.selectedDeviceId);
    const isOnline = cached.length > 0 ? cached[0].online : false;
    if (!isOnline) {
      promptAction.showToast({ message: '设备离线，拒绝发送命令' });
      throw new Error('Device offline');
    }

    let commandStr = '';
    if (actuator === 'LED') {
      commandStr = targetState ? CMD_LED_ON : CMD_LED_OFF;
    } else if (actuator === 'BEEP') {
      commandStr = targetState ? CMD_BEEP_ON : CMD_BEEP_OFF;
    } else if (actuator === 'SPRAY') {
      commandStr = targetState ? CMD_SPRAY_ON : CMD_SPRAY_OFF;
    } else if (actuator === 'IRRIG') {
      commandStr = targetState ? CMD_IRRIG_ON : CMD_IRRIG_OFF;
    }

    try {
      // 2. Call CommandService.send()
      const resp = await CommandService.send(this.selectedDeviceId, commandStr, COMMAND_SOURCE_MANUAL_APP);
      const commandId = resp.command_id;

      // 3. Verification micro-polling loop: 1s interval, up to 5 times
      let confirmed = false;
      for (let i = 0; i < 5; i++) {
        await sleep(1000);
        if (this.isDestroyed) return;
        
        const logsData = await CommandService.getLogs(this.selectedDeviceId, undefined, undefined, undefined, 1, 10);
        const log = logsData.records.find((l: CommandLog): boolean => l.command_id === commandId);
        
        if (log !== undefined) {
          if (log.result_code === 0) {
            confirmed = true;
            break;
          } else {
            promptAction.showToast({ message: `执行失败: ${log.result_msg}` });
            throw new Error(`Device rejected command: ${log.result_msg}`);
          }
        }
      }

      if (!confirmed) {
        promptAction.showToast({ message: '执行验证超时，已回滚' });
        // Force refresh devices cache
        try {
          await DeviceService.refreshDevices(this.selectedDeviceId);
        } catch (refreshErr) {
          console.error('Refresh devices list failed:', JSON.stringify(refreshErr));
        }
        throw new Error('Verification timeout');
      }

      promptAction.showToast({ message: '操作成功并已执行' });
      await this.fetchLogs();
    } catch (err) {
      if (err instanceof Error && err.message !== 'Device offline' && !err.message.includes('rejected') && !err.message.includes('timeout')) {
        promptAction.showToast({ message: err.message });
      }
      throw err as Error;
    }
  }

  build() {
    NavDestination() {
      Column() {
        ConnectivityIndicator({ status: this.connectivity })

        // Device Header Card
        Column() {
          Row() {
            Column() {
              Text(this.deviceName)
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1e2a38')
              Text(`ID: ${this.selectedDeviceId}`)
                .fontSize(12)
                .fontColor('#7f8c8d')
                .margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Start)

            Blank()

            Row() {
              Circle({ width: 8, height: 8 })
                .fill(this.isOnline ? '#4cd9c0' : '#F44336')
              Text(this.isOnline ? ' 在线' : ' 离线')
                .fontSize(14)
                .fontColor(this.isOnline ? '#4cd9c0' : '#F44336')
                .margin({ left: 4 })
            }
          }
          .width('100%')
        }
        .padding(16)
        .width('95%')
        .margin({ top: 12, bottom: 8 })
        .backgroundColor('rgba(255, 255, 255, 0.75)')
        .border({ width: 1, color: 'rgba(104, 159, 210, 0.15)' })
        .borderRadius(16)
        .shadow({ radius: 24, color: 'rgba(104, 159, 210, 0.08)', offsetX: 0, offsetY: 8 })

        Scroll() {
          Column() {
            // Control Panels Section
            Text('设备状态控制')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1e2a38')
              .alignSelf(ItemAlign.Start)
              .margin({ left: 16, top: 12, bottom: 8 })

            Column({ space: 10 }) {
              // LED Row
              Row() {
                Column() {
                  Text('作物补光灯 (LED)')
                    .fontSize(15)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#1e2a38')
                  Text('调节农田植物的光照时长与强度')
                    .fontSize(11)
                    .fontColor('#7f8c8d')
                    .margin({ top: 4 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                ControlButton({
                  isOn: $isLedOn,
                  label: '作物补光灯 (LED)',
                  onToggle: async (target: boolean): Promise<void> => {
                    await this.executeCommand('LED', target);
                  }
                })
              }
              .width('100%')
              .padding(14)
              .backgroundColor('rgba(255, 255, 255, 0.75)')
              .border({ width: 1, color: 'rgba(104, 159, 210, 0.15)' })
              .borderRadius(16)
              .shadow({ radius: 24, color: 'rgba(104, 159, 210, 0.08)', offsetX: 0, offsetY: 8 })

              // BEEP Row
              Row() {
                Column() {
                  Text('警报蜂鸣器 (BEEP)')
                    .fontSize(15)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#1e2a38')
                  Text('检测到环境异常或入侵时发出蜂鸣警报')
                    .fontSize(11)
                    .fontColor('#7f8c8d')
                    .margin({ top: 4 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                ControlButton({
                  isOn: $isBeepOn,
                  label: '警报蜂鸣器 (BEEP)',
                  onToggle: async (target: boolean): Promise<void> => {
                    await this.executeCommand('BEEP', target);
                  }
                })
              }
              .width('100%')
              .padding(14)
              .backgroundColor('rgba(255, 255, 255, 0.75)')
              .border({ width: 1, color: 'rgba(104, 159, 210, 0.15)' })
              .borderRadius(16)
              .shadow({ radius: 24, color: 'rgba(104, 159, 210, 0.08)', offsetX: 0, offsetY: 8 })

              // SPRAY Row
              Row() {
                Column() {
                  Text('降温喷淋阀 (SPRAY)')
                    .fontSize(15)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#1e2a38')
                  Text('快速降低环境温度与提高相对湿度')
                    .fontSize(11)
                    .fontColor('#7f8c8d')
                    .margin({ top: 4 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                ControlButton({
                  isOn: $isSprayOn,
                  label: '降温喷淋阀 (SPRAY)',
                  onToggle: async (target: boolean): Promise<void> => {
                    await this.executeCommand('SPRAY', target);
                  }
                })
              }
              .width('100%')
              .padding(14)
              .backgroundColor('rgba(255, 255, 255, 0.75)')
              .border({ width: 1, color: 'rgba(104, 159, 210, 0.15)' })
              .borderRadius(16)
              .shadow({ radius: 24, color: 'rgba(104, 159, 210, 0.08)', offsetX: 0, offsetY: 8 })

              // IRRIG Row
              Row() {
                Column() {
                  Text('智能灌溉水泵 (IRRIG)')
                    .fontSize(15)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#1e2a38')
                  Text('控制土壤湿度，提供作物生长所需水分')
                    .fontSize(11)
                    .fontColor('#7f8c8d')
                    .margin({ top: 4 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                ControlButton({
                  isOn: $isIrrigOn,
                  label: '智能灌溉水泵 (IRRIG)',
                  onToggle: async (target: boolean): Promise<void> => {
                    await this.executeCommand('IRRIG', target);
                  }
                })
              }
              .width('100%')
              .padding(14)
              .backgroundColor('rgba(255, 255, 255, 0.75)')
              .border({ width: 1, color: 'rgba(104, 159, 210, 0.15)' })
              .borderRadius(16)
              .shadow({ radius: 24, color: 'rgba(104, 159, 210, 0.08)', offsetX: 0, offsetY: 8 })
            }
            .width('95%')

            // Command History Section
            Text('控制历史日志')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1e2a38')
              .alignSelf(ItemAlign.Start)
              .margin({ left: 16, top: 20, bottom: 8 })

            if (this.isLoadingLogs) {
              LoadingState({ status: 'loading', errorMessage: '' })
            } else if (this.logsError !== '') {
              LoadingState({
                status: 'error',
                errorMessage: this.logsError,
                onRetry: () => {
                  this.refreshPageData();
                }
              })
            } else if (this.logs.length === 0) {
              LoadingState({ status: 'empty', errorMessage: '' })
            } else {
              Column() {
                ForEach(this.logs, (log: CommandLog) => {
                  Row() {
                    Column() {
                      Row() {
                        Text(log.command)
                          .fontSize(14)
                          .fontWeight(FontWeight.Bold)
                          .fontColor('#1e2a38')
                        Text(log.source === COMMAND_SOURCE_MANUAL_APP ? 'APP手动' : '自动系统')
                          .fontSize(11)
                          .fontColor('#689fd2')
                          .backgroundColor('rgba(104, 159, 210, 0.1)')
                          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                          .borderRadius(4)
                          .margin({ left: 8 })
                      }
                      
                      Text(`执行时间: ${formatTimestamp(log.timestamp)}`)
                        .fontSize(12)
                        .fontColor('#7f8c8d')
                        .margin({ top: 4 })
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)

                    Column() {
                      if (log.result_code === 0) {
                        Text('成功')
                          .fontSize(13)
                          .fontColor('#4cd9c0')
                          .fontWeight(FontWeight.Bold)
                      } else {
                        Text('失败')
                          .fontSize(13)
                          .fontColor('#F44336')
                          .fontWeight(FontWeight.Bold)
                        Text(log.result_msg || '未知错误')
                          .fontSize(10)
                          .fontColor('#7f8c8d')
                          .margin({ top: 2 })
                      }
                    }
                    .alignItems(HorizontalAlign.End)
                  }
                  .width('100%')
                  .padding({ top: 12, bottom: 12 })
                  .border({ width: { bottom: 1 }, color: 'rgba(104, 159, 210, 0.1)' })
                })
              }
              .width('95%')
              .padding({ left: 14, right: 14, top: 4, bottom: 4 })
              .margin({ bottom: 20 })
              .backgroundColor('rgba(255, 255, 255, 0.75)')
              .border({ width: 1, color: 'rgba(104, 159, 210, 0.15)' })
              .borderRadius(16)
              .shadow({ radius: 24, color: 'rgba(104, 159, 210, 0.08)', offsetX: 0, offsetY: 8 })
            }
          }
          .width('100%')
        }
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#f5f7fa')
    }
    .title('设备远程控制')
  }
}
