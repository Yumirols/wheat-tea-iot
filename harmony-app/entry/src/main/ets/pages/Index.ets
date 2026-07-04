import { DeviceInfo, SensorSnapshot, ConnectivityStatus } from '../common/models';
import { DeviceService } from '../services/DeviceService';
import { SensorService } from '../services/SensorService';
import { PollingManager } from '../services/PollingManager';
import { parseAlarmFlag } from '../common/utils';
import {
  POLL_INTERVAL_INDEX_SENSOR_MS,
  POLL_INTERVAL_INDEX_ALARM_MS
} from '../common/constants';
import { DeviceSelector } from '../components/DeviceSelector';
import { ConnectivityIndicator } from '../components/ConnectivityIndicator';
import { AlarmBanner } from '../components/AlarmBanner';
import { SensorCard } from '../components/SensorCard';
import { LoadingState } from '../components/LoadingState';

// Importing subpages so they can be rendered by pageMap
import { DashboardPage } from './DashboardPage';
import { DiseaseRecordsPage } from './DiseaseRecordsPage';
import { ControlPage } from './ControlPage';
import { AdvisoryPage } from './AdvisoryPage';

@Entry
@Component
struct Index {
  @State pageStack: NavPathStack = new NavPathStack();
  @StorageLink('selectedDeviceId') @Watch('onDeviceIdChanged') selectedDeviceId: string = '';
  @State devices: DeviceInfo[] = [];
  @State latestSnapshot: SensorSnapshot | null = null;
  @State connectivity: ConnectivityStatus = 'loading';
  @State bannerMessage: string = '';
  @State bannerSeverity: string = 'mild';
  @State isBannerVisible: boolean = false;
  @State isLoadingDevices: boolean = true;
  @State deviceError: string = '';

  private isDestroyed: boolean = false;

  aboutToAppear(): void {
    this.isDestroyed = false;
    this.loadDevices();
  }

  aboutToDisappear(): void {
    this.isDestroyed = true;
    PollingManager.stop('index_sensor');
    PollingManager.stop('index_alarm');
  }

  onDeviceIdChanged(): void {
    if (this.isDestroyed) return;
    this.startPolling();
    this.fetchLatestSensor();
    this.fetchAlarmStatus();
  }

  private async loadDevices(): Promise<void> {
    this.isLoadingDevices = true;
    this.deviceError = '';
    try {
      const list = await DeviceService.getDeviceList();
      if (this.isDestroyed) return;
      this.devices = list;
      if (list.length > 0) {
        const stored = AppStorage.get<string>('selectedDeviceId');
        const hasStored = list.some((d: DeviceInfo): boolean => d.device_id === stored);
        if (!hasStored) {
          AppStorage.setOrCreate('selectedDeviceId', list[0].device_id);
        }
      }
      this.connectivity = 'online';
    } catch (err) {
      if (this.isDestroyed) return;
      this.deviceError = err instanceof Error ? err.message : '加载设备列表失败';
      this.connectivity = 'offline';
    } finally {
      if (this.isDestroyed) return;
      this.isLoadingDevices = false;
      this.startPolling();
      this.fetchLatestSensor();
      this.fetchAlarmStatus();
    }
  }

  private startPolling(): void {
    if (!this.selectedDeviceId) {
      return;
    }
    PollingManager.start('index_sensor', async () => {
      await this.fetchLatestSensor();
    }, POLL_INTERVAL_INDEX_SENSOR_MS);

    PollingManager.start('index_alarm', async () => {
      await this.fetchAlarmStatus();
    }, POLL_INTERVAL_INDEX_ALARM_MS);
  }

  private async fetchLatestSensor(): Promise<void> {
    if (!this.selectedDeviceId) return;
    try {
      const snapshot = await SensorService.getLatest(this.selectedDeviceId);
      if (this.isDestroyed) return;
      this.latestSnapshot = snapshot;
    } catch (err) {
      if (this.isDestroyed) return;
      console.error('Index fetchLatestSensor error:', JSON.stringify(err));
    }
  }

  private async fetchAlarmStatus(): Promise<void> {
    if (!this.selectedDeviceId) return;
    try {
      const cached = DeviceService.getCachedDevices(this.selectedDeviceId);
      let isOnline = false;
      if (cached.length > 0) {
        isOnline = cached[0].online;
      }
      this.connectivity = isOnline ? 'online' : 'offline';

      const snapshot = await SensorService.getLatest(this.selectedDeviceId);
      if (this.isDestroyed) return;
      if (snapshot && snapshot.alarm_flag > 0) {
        const labels = parseAlarmFlag(snapshot.alarm_flag);
        if (labels.length > 0) {
          this.bannerMessage = `警告：设备 [${this.selectedDeviceId}] 检测到异常: ${labels.join(', ')}`;
          this.bannerSeverity = 'severe';
          this.isBannerVisible = true;
        } else {
          this.isBannerVisible = false;
        }
      } else {
        this.isBannerVisible = false;
      }
    } catch (err) {
      if (this.isDestroyed) return;
      console.error('Index fetchAlarmStatus error:', JSON.stringify(err));
    }
  }

  @Builder
  pageMap(name: string) {
    if (name === 'DashboardPage') {
      DashboardPage()
    } else if (name === 'DiseaseRecordsPage') {
      DiseaseRecordsPage()
    } else if (name === 'ControlPage') {
      ControlPage()
    } else if (name === 'AdvisoryPage') {
      AdvisoryPage()
    }
  }

  @Builder
  customTitle() {
    Row({ space: 8 }) {
      Text('农眼卫视终端')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1e2a38')
      if (!this.isLoadingDevices && this.devices.length > 0) {
        DeviceSelector({ devices: this.devices })
      }
    }
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Navigation(this.pageStack) {
      Column() {

        // Status Indicators
        ConnectivityIndicator({ status: this.connectivity })

        if (this.isBannerVisible) {
          AlarmBanner({
            message: this.bannerMessage,
            severity: this.bannerSeverity,
            onClose: () => {
              this.isBannerVisible = false;
            },
            onTap: () => {
              this.pageStack.pushPathByName('AdvisoryPage', null);
            }
          })
        }

        Scroll() {
          Column() {
            if (this.isLoadingDevices) {
              LoadingState({ status: 'loading', errorMessage: '' })
            } else if (this.deviceError !== '') {
              LoadingState({
                status: 'error',
                errorMessage: this.deviceError,
                onRetry: () => {
                  this.loadDevices();
                }
              })
            } else if (this.devices.length === 0) {
              LoadingState({ status: 'empty', errorMessage: '' })
            } else {
              // Sensor Data Grid
              Text('环境传感器数据')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1e2a38')
                .alignSelf(ItemAlign.Start)
                .margin({ left: 16, top: 16, bottom: 8 })

              if (this.latestSnapshot === null) {
                LoadingState({ status: 'loading', errorMessage: '' })
              } else {
                Grid() {
                  GridItem() {
                    SensorCard({
                      label: '环境温度',
                      value: this.latestSnapshot.temperature,
                      unit: '℃',
                      timestamp: this.latestSnapshot.timestamp,
                      alarmLabels: (this.latestSnapshot.alarm_flag & 0x03) !== 0 ? ['温'] : []
                    })
                  }
                  GridItem() {
                    SensorCard({
                      label: '环境湿度',
                      value: this.latestSnapshot.humidity,
                      unit: '%',
                      timestamp: this.latestSnapshot.timestamp,
                      alarmLabels: (this.latestSnapshot.alarm_flag & 0x0c) !== 0 ? ['湿'] : []
                    })
                  }
                  GridItem() {
                    SensorCard({
                      label: '光照强度',
                      value: this.latestSnapshot.light,
                      unit: 'lux',
                      timestamp: this.latestSnapshot.timestamp,
                      alarmLabels: (this.latestSnapshot.alarm_flag & 0x10) !== 0 ? ['光'] : []
                    })
                  }
                  GridItem() {
                    SensorCard({
                      label: '二氧化碳',
                      value: this.latestSnapshot.co2,
                      unit: 'ppm',
                      timestamp: this.latestSnapshot.timestamp,
                      alarmLabels: (this.latestSnapshot.alarm_flag & 0x20) !== 0 ? ['碳'] : []
                    })
                  }
                  GridItem() {
                    SensorCard({
                      label: '土壤氮含量',
                      value: this.latestSnapshot.soil_n,
                      unit: 'mg/kg',
                      timestamp: this.latestSnapshot.timestamp,
                      alarmLabels: (this.latestSnapshot.alarm_flag & 0x40) !== 0 ? ['氮'] : []
                    })
                  }
                  GridItem() {
                    SensorCard({
                      label: '土壤磷含量',
                      value: this.latestSnapshot.soil_p,
                      unit: 'mg/kg',
                      timestamp: this.latestSnapshot.timestamp,
                      alarmLabels: (this.latestSnapshot.alarm_flag & 0x80) !== 0 ? ['磷'] : []
                    })
                  }
                  GridItem() {
                    SensorCard({
                      label: '土壤钾含量',
                      value: this.latestSnapshot.soil_k,
                      unit: 'mg/kg',
                      timestamp: this.latestSnapshot.timestamp,
                      alarmLabels: []
                    })
                  }
                  GridItem() {
                    SensorCard({
                      label: '水位距离',
                      value: this.latestSnapshot.distance,
                      unit: 'cm',
                      timestamp: this.latestSnapshot.timestamp,
                      alarmLabels: []
                    })
                  }
                }
                .columnsTemplate('1fr 1fr')
                .rowsGap(8)
                .columnsGap(8)
                .width('95%')
                .height(440)
              }

              // Navigation Cards (VN Style)
              Text('功能模块')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1e2a38')
                .alignSelf(ItemAlign.Start)
                .margin({ left: 16, top: 20, bottom: 8 })

              Column({ space: 10 }) {
                this.NavCard('环境数据分析', '查看温湿度、CO2等传感器历史趋势曲线', 'DashboardPage', '#689fd2')
                this.NavCard('病虫害记录', '麦草作物病害AI自动检测与分类识别历史', 'DiseaseRecordsPage', '#b39ddb')
                this.NavCard('设备远程控制', '远程开启或关闭LED灯、警报蜂鸣器、水泵', 'ControlPage', '#4cd9c0')
                this.NavCard('AI 防治建议', '基于大模型联动分析提供最优农业生产防治决策', 'AdvisoryPage', '#f48fb1')
              }
              .width('95%')
              .margin({ bottom: 20 })
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
    .title(this.customTitle)
    .titleMode(NavigationTitleMode.Mini)
    .navDestination(this.pageMap)
  }

  @Builder
  NavCard(title: string, desc: string, targetPage: string, iconColor: string) {
    Row() {
      // Color Indicator
      Circle({ width: 12, height: 12 })
        .fill(iconColor)
        .margin({ right: 12 })

      Column() {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1e2a38')
        Text(desc)
          .fontSize(12)
          .fontColor('#7f8c8d')
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('➔')
        .fontSize(16)
        .fontColor('#7f8c8d')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('rgba(255, 255, 255, 0.75)')
    .border({ width: 1, color: 'rgba(104, 159, 210, 0.15)' })
    .borderRadius(16)
    .shadow({ radius: 24, color: 'rgba(104, 159, 210, 0.08)', offsetX: 0, offsetY: 8 })
    .onClick(() => {
      this.pageStack.pushPathByName(targetPage, null);
    })
  }
}

