import { Advisory, ConnectivityStatus } from '../common/models';
import { AdvisoryService } from '../services/AdvisoryService';
import { DeviceService } from '../services/DeviceService';
import { PollingManager } from '../services/PollingManager';
import { POLL_INTERVAL_ADVISORY_MS } from '../common/constants';
import { formatTimestamp } from '../common/utils';
import { ConnectivityIndicator } from '../components/ConnectivityIndicator';
import { LoadingState } from '../components/LoadingState';
import { SeverityBadge } from '../components/SeverityBadge';

@Component
export struct AdvisoryPage {
  @StorageLink('selectedDeviceId') @Watch('onDeviceIdChanged') selectedDeviceId: string = '';
  @State private deviceName: string = '';
  @State private connectivity: ConnectivityStatus = 'loading';
  @State private advisoryData: Advisory | null = null;
  @State private isLoading: boolean = true;
  @State private errorMessage: string = '';

  private isDestroyed: boolean = false;

  // ── LinkageCard helpers ─────────────────────────────────────────────────
  private getLinkageRiskLevel(): string {
    return this.advisoryData?.env_disease_linkage?.risk_level || '';
  }

  private isHighRisk(): boolean {
    const r = this.getLinkageRiskLevel();
    return r === 'HIGH' || r === '高' || r === 'severe';
  }

  private isMedRisk(): boolean {
    const r = this.getLinkageRiskLevel();
    return r === 'MEDIUM' || r === '中' || r === 'moderate';
  }

  private getLinkageBgColor(): string {
    const hasLinkage = this.advisoryData !== null && this.advisoryData.env_disease_linkage !== null;
    if (!hasLinkage) return 'rgba(255, 255, 255, 0.75)';
    if (this.isHighRisk()) return 'rgba(244, 143, 177, 0.12)';
    if (this.isMedRisk()) return 'rgba(179, 157, 219, 0.12)';
    return 'rgba(255, 255, 255, 0.75)';
  }

  private getLinkageBorderColor(): string {
    const hasLinkage = this.advisoryData !== null && this.advisoryData.env_disease_linkage !== null;
    if (!hasLinkage) return 'rgba(104, 159, 210, 0.15)';
    if (this.isHighRisk()) return '#f48fb1';
    if (this.isMedRisk()) return '#b39ddb';
    return 'rgba(104, 159, 210, 0.15)';
  }

  private getRiskBadgeColor(): string {
    if (this.isHighRisk()) return '#f48fb1';
    if (this.isMedRisk()) return '#b39ddb';
    return '#7f8c8d';
  }

  private getLinkageConditions(): string[] {
    return this.advisoryData?.env_disease_linkage?.matched_conditions || [];
  }

  aboutToAppear(): void {
    this.isDestroyed = false;
    this.refreshData();
    this.startPolling();
  }

  aboutToDisappear(): void {
    this.isDestroyed = true;
    PollingManager.stop('advisory_refresh');
  }

  onDeviceIdChanged(): void {
    if (this.isDestroyed) return;
    this.refreshData();
    this.startPolling();
  }

  private startPolling(): void {
    if (!this.selectedDeviceId) return;
    PollingManager.start('advisory_refresh', async () => {
      await this.fetchAdvisory();
    }, POLL_INTERVAL_ADVISORY_MS);
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
      await this.fetchAdvisory();
    } catch (err) {
      if (this.isDestroyed) return;
      this.errorMessage = err instanceof Error ? err.message : '获取AI防治建议失败';
    } finally {
      if (this.isDestroyed) return;
      this.isLoading = false;
    }
  }

  private async fetchAdvisory(): Promise<void> {
    if (!this.selectedDeviceId) return;

    // Resolve online status for connectivity
    const cached = DeviceService.getCachedDevices(this.selectedDeviceId);
    if (cached.length > 0) {
      this.deviceName = cached[0].device_name;
      this.connectivity = cached[0].online ? 'online' : 'offline';
    } else {
      this.deviceName = this.selectedDeviceId;
      this.connectivity = 'offline';
    }

    const data = await AdvisoryService.getAdvisory(this.selectedDeviceId);
    if (this.isDestroyed) return;
    this.advisoryData = data;
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
            Text('AI 实时决策')
              .fontSize(12)
              .fontColor('#ffffff')
              .backgroundColor('#4cd9c0')
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .borderRadius(8)
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
        } else if (this.advisoryData === null) {
          LoadingState({ status: 'empty', errorMessage: '' })
        } else {
          Scroll() {
            Column({ space: 12 }) {
              
              // 1. Latest Disease Card
              this.DiseaseCard()

              // 2. Env Snapshot Card
              this.EnvCard()

              // 3. Linkage Analysis Card (Pink/Lavender styling based on risk level)
              this.LinkageCard()

              // 4. Action Advisory Card
              this.ActionCard()

            }
            .width('95%')
            .margin({ bottom: 20 })
          }
          .layoutWeight(1)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#f5f7fa')
    }
    .title('AI 防治建议')
  }

  @Builder
  DiseaseCard() {
    Column() {
      Row() {
        Circle({ width: 8, height: 8 }).fill('#b39ddb')
        Text('最新作物病害监测')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1e2a38')
          .margin({ left: 8 })
      }
      .width('100%')
      .margin({ bottom: 10 })

      if (this.advisoryData !== null && this.advisoryData.latest_detection !== null) {
        Column({ space: 6 }) {
          Row() {
            Text('作物类型:')
              .fontSize(13)
              .fontColor('#7f8c8d')
            Blank()
            Text(this.advisoryData.latest_detection.crop_type === 'wheat' ? '小麦' : this.advisoryData.latest_detection.crop_type === 'tea' ? '茶叶' : this.advisoryData.latest_detection.crop_type)
              .fontSize(13)
              .fontColor('#1e2a38')
              .fontWeight(FontWeight.Medium)
          }.width('100%')

          Row() {
            Text('病害种类:')
              .fontSize(13)
              .fontColor('#7f8c8d')
            Blank()
            Text(this.advisoryData.latest_detection.disease_type)
              .fontSize(13)
              .fontColor('#1e2a38')
              .fontWeight(FontWeight.Medium)
          }.width('100%')

          Row() {
            Text('严重程度:')
              .fontSize(13)
              .fontColor('#7f8c8d')
            Blank()
            SeverityBadge({ severity: this.advisoryData.latest_detection.severity })
          }.width('100%')

          Row() {
            Text('置信度:')
              .fontSize(13)
              .fontColor('#7f8c8d')
            Blank()
            Text(`${(this.advisoryData.latest_detection.confidence * 100).toFixed(1)}%`)
              .fontSize(13)
              .fontColor('#1e2a38')
              .fontWeight(FontWeight.Medium)
          }.width('100%')

          Row() {
            Text('识别时间:')
              .fontSize(13)
              .fontColor('#7f8c8d')
            Blank()
            Text(formatTimestamp(this.advisoryData.latest_detection.timestamp))
              .fontSize(12)
              .fontColor('#1e2a38')
          }.width('100%')
        }
        .width('100%')
      } else {
        Text('暂无近期病害检测记录')
          .fontSize(13)
          .fontColor('#7f8c8d')
          .padding({ top: 10, bottom: 10 })
      }
    }
    .padding(14)
    .backgroundColor('rgba(255, 255, 255, 0.75)')
    .border({ width: 1, color: 'rgba(104, 159, 210, 0.15)' })
    .borderRadius(16)
    .shadow({ radius: 24, color: 'rgba(104, 159, 210, 0.08)', offsetX: 0, offsetY: 8 })
  }

  @Builder
  EnvCard() {
    Column() {
      Row() {
        Circle({ width: 8, height: 8 }).fill('#689fd2')
        Text('当前环境监测快照')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1e2a38')
          .margin({ left: 8 })
      }
      .width('100%')
      .margin({ bottom: 10 })

      if (this.advisoryData !== null && this.advisoryData.current_env !== null) {
        Grid() {
          GridItem() {
            this.EnvMiniItem('温度', `${this.advisoryData.current_env.temperature} ℃`)
          }
          GridItem() {
            this.EnvMiniItem('湿度', `${this.advisoryData.current_env.humidity} %`)
          }
          GridItem() {
            this.EnvMiniItem('光照', `${this.advisoryData.current_env.light} lux`)
          }
          GridItem() {
            this.EnvMiniItem('CO2', `${this.advisoryData.current_env.co2} ppm`)
          }
        }
        .columnsTemplate('1fr 1fr')
        .rowsGap(8)
        .columnsGap(8)
        .width('100%')
        .height(100)
      } else {
        Text('暂无环境快照数据')
          .fontSize(13)
          .fontColor('#7f8c8d')
          .padding({ top: 10, bottom: 10 })
      }
    }
    .padding(14)
    .backgroundColor('rgba(255, 255, 255, 0.75)')
    .border({ width: 1, color: 'rgba(104, 159, 210, 0.15)' })
    .borderRadius(16)
    .shadow({ radius: 24, color: 'rgba(104, 159, 210, 0.08)', offsetX: 0, offsetY: 8 })
  }

  @Builder
  EnvMiniItem(label: string, val: string) {
    Row() {
      Text(label)
        .fontSize(12)
        .fontColor('#7f8c8d')
      Blank()
      Text(val)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor('#34495e')
    }
    .width('100%')
    .padding(8)
    .backgroundColor('rgba(255, 255, 255, 0.5)')
    .borderRadius(8)
  }

  @Builder
  LinkageCard() {
    Column() {
      if (this.advisoryData !== null && this.advisoryData.env_disease_linkage !== null) {
        Row() {
          Circle({ width: 8, height: 8 }).fill(this.getRiskBadgeColor())
          Text('环境-病理联动风险分析')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1e2a38')
            .margin({ left: 8 })
          Blank()
          Text(`风险等级: ${this.getLinkageRiskLevel()}`)
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor('#ffffff')
            .backgroundColor(this.getRiskBadgeColor())
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(4)
        }
        .width('100%')
        .margin({ bottom: 10 })

        Column({ space: 8 }) {
          // Conditions Matched List
          Column({ space: 4 }) {
            Text('匹配诱发环境条件:')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#34495e')
              .alignSelf(ItemAlign.Start)

            if (this.getLinkageConditions().length === 0) {
              Text('• 无明显病虫害诱发环境条件')
                .fontSize(12)
                .fontColor('#7f8c8d')
                .alignSelf(ItemAlign.Start)
                .margin({ left: 4 })
            } else {
              ForEach(this.getLinkageConditions(), (cond: string) => {
                Text(`• ${cond}`)
                  .fontSize(12)
                  .fontColor('#34495e')
                  .alignSelf(ItemAlign.Start)
                  .margin({ left: 4 })
              })
            }
          }
          .width('100%')
          .padding(8)
          .backgroundColor('rgba(255, 255, 255, 0.4)')
          .borderRadius(8)

          // Linkage Recommendation
          Column({ space: 4 }) {
            Text('联动决策结论:')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#34495e')
              .alignSelf(ItemAlign.Start)
            Text(this.advisoryData?.env_disease_linkage?.recommendation || '暂无分析结论')
              .fontSize(12.5)
              .fontColor('#1e2a38')
              .alignSelf(ItemAlign.Start)
              .lineHeight(18)
          }
          .width('100%')
        }
        .width('100%')
      } else {
        Row() {
          Circle({ width: 8, height: 8 }).fill('#7f8c8d')
          Text('环境-病理联动风险分析')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1e2a38')
            .margin({ left: 8 })
        }
        .width('100%')
        .margin({ bottom: 10 })

        Text('暂无联动分析报告')
          .fontSize(13)
          .fontColor('#7f8c8d')
          .padding({ top: 10, bottom: 10 })
      }
    }
    .padding(14)
    .backgroundColor(this.getLinkageBgColor())
    .border({
      width: 1,
      color: this.getLinkageBorderColor()
    })
    .borderRadius(16)
    .shadow({ radius: 24, color: 'rgba(104, 159, 210, 0.08)', offsetX: 0, offsetY: 8 })
  }

  @Builder
  ActionCard() {
    Column() {
      Row() {
        Circle({ width: 8, height: 8 }).fill('#4cd9c0')
        Text('AI 专家防治建议')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1e2a38')
          .margin({ left: 8 })
      }
      .width('100%')
      .margin({ bottom: 10 })

      if (this.advisoryData !== null && this.advisoryData.advisory !== null) {
        Column({ space: 8 }) {
          Row() {
            Text('推荐操作:')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#34495e')
            Blank()
            Text(this.advisoryData.advisory.action)
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#4cd9c0')
          }
          .width('100%')

          Text(this.advisoryData.advisory.description)
            .fontSize(12.5)
            .fontColor('#34495e')
            .lineHeight(18)
            .alignSelf(ItemAlign.Start)

          if (this.advisoryData.advisory.auto_action_triggered) {
            Row() {
              Text('⚠ 触发自动联动控制动作:')
                .fontSize(11)
                .fontWeight(FontWeight.Bold)
                .fontColor('#e57373')
              Blank()
              Text(this.advisoryData.advisory.auto_action || '未指定')
                .fontSize(11)
                .fontWeight(FontWeight.Bold)
                .fontColor('#ffffff')
                .backgroundColor('#e57373')
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .borderRadius(4)
            }
            .width('100%')
            .padding(8)
            .backgroundColor('rgba(229, 115, 115, 0.08)')
            .border({ width: 1, color: 'rgba(229, 115, 115, 0.15)' })
            .borderRadius(8)
            .margin({ top: 4 })
          }
        }
        .width('100%')
      } else {
        Text('暂无生产防治建议')
          .fontSize(13)
          .fontColor('#7f8c8d')
          .padding({ top: 10, bottom: 10 })
      }
    }
    .padding(14)
    .backgroundColor('rgba(255, 255, 255, 0.75)')
    .border({ width: 1, color: 'rgba(104, 159, 210, 0.15)' })
    .borderRadius(16)
    .shadow({ radius: 24, color: 'rgba(104, 159, 210, 0.08)', offsetX: 0, offsetY: 8 })
  }
}
