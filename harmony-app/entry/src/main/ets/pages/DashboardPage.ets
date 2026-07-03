import { DeviceInfo, SensorSnapshot, SensorHistory, ConnectivityStatus } from '../common/models';
import { DeviceService } from '../services/DeviceService';
import { SensorService } from '../services/SensorService';
import { PollingManager } from '../services/PollingManager';
import { POLL_INTERVAL_DASHBOARD_MS } from '../common/constants';
import { ConnectivityIndicator } from '../components/ConnectivityIndicator';
import { SensorCard } from '../components/SensorCard';
import { ChartView } from '../components/ChartView';
import { LoadingState } from '../components/LoadingState';

@Component
export struct DashboardPage {
  @StorageLink('selectedDeviceId') @Watch('onDeviceIdChanged') selectedDeviceId: string = '';
  @State private deviceName: string = '';
  @State private isOnline: boolean = false;
  @State private latestSnapshot: SensorSnapshot | null = null;
  @State private tempHistory: number[] = [];
  @State private humidHistory: number[] = [];
  @State private co2History: number[] = [];
  @State private chartRebuildKey: number = 0;
  @State private isLoading: boolean = true;
  @State private errorMessage: string = '';
  @State private connectivity: ConnectivityStatus = 'loading';

  private isDestroyed: boolean = false;

  aboutToAppear(): void {
    this.isDestroyed = false;
    this.refreshData();
    this.startPolling();
  }

  aboutToDisappear(): void {
    this.isDestroyed = true;
    PollingManager.stop('dashboard_sensor');
  }

  onDeviceIdChanged(): void {
    if (this.isDestroyed) return;
    this.refreshData();
    this.startPolling();
  }

  private startPolling(): void {
    if (!this.selectedDeviceId) return;
    PollingManager.start('dashboard_sensor', async () => {
      await this.fetchLatestData();
    }, POLL_INTERVAL_DASHBOARD_MS);
  }

  private async refreshData(): Promise<void> {
    if (!this.selectedDeviceId) {
      this.isLoading = false;
      this.errorMessage = '未选择设备';
      return;
    }
    this.isLoading = true;
    this.errorMessage = '';
    try {
      await this.fetchLatestData();
    } catch (err) {
      if (this.isDestroyed) return;
      this.errorMessage = err instanceof Error ? err.message : '获取数据失败';
    } finally {
      if (this.isDestroyed) return;
      this.isLoading = false;
    }
  }

  private async fetchLatestData(): Promise<void> {
    if (!this.selectedDeviceId) return;
    
    // Resolve device info from cache
    const cached = DeviceService.getCachedDevices(this.selectedDeviceId);
    if (cached.length > 0) {
      this.deviceName = cached[0].device_name;
      this.isOnline = cached[0].online;
      this.connectivity = this.isOnline ? 'online' : 'offline';
    } else {
      this.deviceName = this.selectedDeviceId;
      this.connectivity = 'offline';
    }

    // Fetch latest snapshot and history (last 10 records for charts)
    const snapshot = await SensorService.getLatest(this.selectedDeviceId);
    const historyData = await SensorService.getHistory(this.selectedDeviceId, undefined, undefined, 1, 10);

    if (this.isDestroyed) return;

    this.latestSnapshot = snapshot;

    // Reverse history to show chronological order (left to right)
    const records = (historyData.records || []).slice().reverse();
    this.tempHistory = records.map((r: SensorHistory): number => r.temperature);
    this.humidHistory = records.map((r: SensorHistory): number => r.humidity);
    this.co2History = records.map((r: SensorHistory): number => r.co2);
    
    this.chartRebuildKey++;
  }

  build() {
    NavDestination() {
      Column() {
        // Connectivity Status
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
                .fill(this.isOnline ? '#4CAF50' : '#F44336')
              Text(this.isOnline ? ' 在线' : ' 离线')
                .fontSize(14)
                .fontColor(this.isOnline ? '#4CAF50' : '#F44336')
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

        if (this.isLoading) {
          LoadingState({ status: 'loading', errorMessage: '' })
        } else if (this.errorMessage !== '') {
          LoadingState({
            status: 'error',
            errorMessage: this.errorMessage,
            onRetry: () => {
              this.refreshData();
            }
          })
        } else {
          Scroll() {
            Column() {
              // Sensor Cards Grid (Real-time snapshots)
              if (this.latestSnapshot !== null) {
                Text('实时数据')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#1e2a38')
                  .alignSelf(ItemAlign.Start)
                  .margin({ left: 16, top: 12, bottom: 8 })

                Grid() {
                  GridItem() {
                    SensorCard({
                      label: '当前温度',
                      value: this.latestSnapshot.temperature,
                      unit: '℃',
                      timestamp: this.latestSnapshot.timestamp,
                      alarmLabels: (this.latestSnapshot.alarm_flag & 0x03) !== 0 ? ['温'] : []
                    })
                  }
                  GridItem() {
                    SensorCard({
                      label: '当前湿度',
                      value: this.latestSnapshot.humidity,
                      unit: '%',
                      timestamp: this.latestSnapshot.timestamp,
                      alarmLabels: (this.latestSnapshot.alarm_flag & 0x0c) !== 0 ? ['湿'] : []
                    })
                  }
                  GridItem() {
                    SensorCard({
                      label: '当前二氧化碳',
                      value: this.latestSnapshot.co2,
                      unit: 'ppm',
                      timestamp: this.latestSnapshot.timestamp,
                      alarmLabels: (this.latestSnapshot.alarm_flag & 0x20) !== 0 ? ['碳'] : []
                    })
                  }
                  GridItem() {
                    SensorCard({
                      label: '当前光照度',
                      value: this.latestSnapshot.light,
                      unit: 'lux',
                      timestamp: this.latestSnapshot.timestamp,
                      alarmLabels: (this.latestSnapshot.alarm_flag & 0x10) !== 0 ? ['光'] : []
                    })
                  }
                }
                .columnsTemplate('1fr 1fr')
                .rowsGap(8)
                .columnsGap(8)
                .width('95%')
                .height(220)
              }

              // History Charts
              Text('历史趋势分析')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1e2a38')
                .alignSelf(ItemAlign.Start)
                .margin({ left: 16, top: 16, bottom: 8 })

              // Charts in custom container cards
              this.ChartCard('温度变化趋势 (℃)', this.tempHistory)
              this.ChartCard('湿度变化趋势 (%)', this.humidHistory)
              this.ChartCard('二氧化碳变化趋势 (ppm)', this.co2History)
            }
            .width('100%')
          }
          .layoutWeight(1)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#f5f7fa')
    }
    .title('环境数据分析')
  }

  @Builder
  ChartCard(title: string, data: number[]) {
    Column() {
      Text(title)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#34495e')
        .alignSelf(ItemAlign.Start)
        .margin({ bottom: 8 })

      if (data.length === 0) {
        Text('暂无历史趋势数据')
          .fontSize(12)
          .fontColor('#7f8c8d')
          .margin({ top: 20, bottom: 20 })
      } else {
        if (this.chartRebuildKey % 2 === 0) {
          ChartView({
            chartType: 'line',
            dataPoints: data,
            canvasWidth: 320,
            canvasHeight: 150
          })
        } else {
          ChartView({
            chartType: 'line',
            dataPoints: data,
            canvasWidth: 320,
            canvasHeight: 150
          })
        }
      }
    }
    .padding(16)
    .width('95%')
    .margin({ bottom: 12 })
    .backgroundColor('rgba(255, 255, 255, 0.75)')
    .border({ width: 1, color: 'rgba(104, 159, 210, 0.15)' })
    .borderRadius(16)
    .shadow({ radius: 24, color: 'rgba(104, 159, 210, 0.08)', offsetX: 0, offsetY: 8 })
  }
}
