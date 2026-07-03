import { DiseaseRecord, PaginatedData } from '../common/models';
import { DiseaseService } from '../services/DiseaseService';
import { formatTimestamp } from '../common/utils';
import { SeverityBadge } from '../components/SeverityBadge';
import { ImageViewer } from '../components/ImageViewer';
import { LoadingState } from '../components/LoadingState';
import { PaginatedList } from '../components/PaginatedList';

function extractImageId(imagePath: string): string {
  if (!imagePath) return '';
  const parts = imagePath.split('/');
  const filename = parts[parts.length - 1];
  const dotIndex = filename.lastIndexOf('.');
  if (dotIndex > 0) {
    return filename.substring(0, dotIndex);
  }
  return filename;
}

@Component
export struct DiseaseRecordsPage {
  @StorageLink('selectedDeviceId') @Watch('onFilterChanged') selectedDeviceId: string = '';
  @State @Watch('onFilterChanged') private cropFilter: string = '';
  @State @Watch('onFilterChanged') private severityFilter: string = '';
  @State private isDetailOpen: boolean = false;
  @State private selectedRecord: DiseaseRecord | null = null;
  @State private pageSize: number = 10;
  @State private listRebuildKey: number = 0;
  
  private isDestroyed: boolean = false;

  aboutToAppear(): void {
    this.isDestroyed = false;
  }

  aboutToDisappear(): void {
    this.isDestroyed = true;
  }

  onFilterChanged(): void {
    if (this.isDestroyed) return;
    this.listRebuildKey++;
  }

  @Builder
  renderDiseaseItem(item: DiseaseRecord, index: number) {
    ListItem() {
      Row() {
        Column() {
          Row() {
            Text(item.crop_type === 'wheat' ? '小麦' : item.crop_type === 'tea' ? '茶叶' : item.crop_type)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1e2a38')
            Text(item.disease_type)
              .fontSize(14)
              .fontColor('#34495e')
              .margin({ left: 8 })
          }
          .alignItems(VerticalAlign.Center)

          Text(`检测时间: ${formatTimestamp(item.timestamp)}`)
            .fontSize(12)
            .fontColor('#7f8c8d')
            .margin({ top: 6 })
          
          Text(`置信度: ${(item.confidence * 100).toFixed(1)}%`)
            .fontSize(12)
            .fontColor('#7f8c8d')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Column() {
          SeverityBadge({ severity: item.severity })
          Text('查看详情 ➔')
            .fontSize(11)
            .fontColor('#689fd2')
            .margin({ top: 8 })
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('95%')
      .padding(14)
      .margin({ left: '2.5%', bottom: 8 })
      .backgroundColor('rgba(255, 255, 255, 0.75)')
      .border({ width: 1, color: 'rgba(104, 159, 210, 0.15)' })
      .borderRadius(12)
      .shadow({ radius: 12, color: 'rgba(104, 159, 210, 0.04)', offsetX: 0, offsetY: 4 })
      .onClick(() => {
        this.selectedRecord = item;
        this.isDetailOpen = true;
      })
    }
  }

  build() {
    NavDestination() {
      Stack() {
        Column() {
          // Filters Bar
          Column() {
            // Crop Filter Chips
            Row() {
              Text('作物筛选:')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('#34495e')
                .margin({ right: 8 })
              
              Row({ space: 8 }) {
                this.FilterChip('全部', '', this.cropFilter === '', (val) => { this.cropFilter = val; })
                this.FilterChip('小麦', 'wheat', this.cropFilter === 'wheat', (val) => { this.cropFilter = val; })
                this.FilterChip('茶叶', 'tea', this.cropFilter === 'tea', (val) => { this.cropFilter = val; })
              }
            }
            .width('100%')
            .padding({ bottom: 8 })

            // Severity Filter Chips
            Row() {
              Text('严重程度:')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('#34495e')
                .margin({ right: 8 })
              
              Row({ space: 8 }) {
                this.FilterChip('全部', '', this.severityFilter === '', (val) => { this.severityFilter = val; })
                this.FilterChip('轻度', 'mild', this.severityFilter === 'mild', (val) => { this.severityFilter = val; })
                this.FilterChip('中度', 'moderate', this.severityFilter === 'moderate', (val) => { this.severityFilter = val; })
                this.FilterChip('重度', 'severe', this.severityFilter === 'severe', (val) => { this.severityFilter = val; })
              }
            }
            .width('100%')
          }
          .padding(12)
          .width('95%')
          .margin({ top: 12, bottom: 8 })
          .backgroundColor('rgba(255, 255, 255, 0.75)')
          .border({ width: 1, color: 'rgba(104, 159, 210, 0.15)' })
          .borderRadius(16)
          .shadow({ radius: 24, color: 'rgba(104, 159, 210, 0.08)', offsetX: 0, offsetY: 8 })

          Column() {
            if (this.listRebuildKey % 2 === 0) {
              PaginatedList({
                renderItem: (item: DiseaseRecord, index: number) => { this.renderDiseaseItem(item, index); },
                loadPage: (page: number): Promise<PaginatedData<DiseaseRecord>> => {
                  return DiseaseService.getList({
                    device_id: this.selectedDeviceId !== '' ? this.selectedDeviceId : undefined,
                    crop_type: this.cropFilter !== '' ? this.cropFilter : undefined,
                    severity: this.severityFilter !== '' ? this.severityFilter : undefined,
                    page: page,
                    page_size: this.pageSize
                  });
                },
                pageSize: this.pageSize
              })
            } else {
              PaginatedList({
                renderItem: (item: DiseaseRecord, index: number) => { this.renderDiseaseItem(item, index); },
                loadPage: (page: number): Promise<PaginatedData<DiseaseRecord>> => {
                  return DiseaseService.getList({
                    device_id: this.selectedDeviceId !== '' ? this.selectedDeviceId : undefined,
                    crop_type: this.cropFilter !== '' ? this.cropFilter : undefined,
                    severity: this.severityFilter !== '' ? this.severityFilter : undefined,
                    page: page,
                    page_size: this.pageSize
                  });
                },
                pageSize: this.pageSize
              })
            }
          }
          .layoutWeight(1)
          .width('100%')
        }
        .width('100%')
        .height('100%')

        // Detail Modal Overlay
        if (this.isDetailOpen && this.selectedRecord !== null) {
          Column() {
            // Semi-translucent overlay background
            Column() {
              // Dialog Box
              Column() {
                // Header
                Row() {
                  Text('病虫害详细记录')
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#1e2a38')
                  Blank()
                  Text('✕')
                    .fontSize(18)
                    .fontColor('#7f8c8d')
                    .onClick(() => {
                      this.isDetailOpen = false;
                    })
                }
                .width('100%')
                .padding({ bottom: 12 })
                .border({ width: { bottom: 1 }, color: 'rgba(104, 159, 210, 0.1)' })

                Scroll() {
                  Column() {
                    // Image Viewer Panel
                    Column() {
                      ImageViewer({
                        imagePath: this.selectedRecord.image_path,
                        imageId: extractImageId(this.selectedRecord.image_path)
                      })
                    }
                    .width('100%')
                    .height(200)
                    .borderRadius(8)
                    .clip(true)
                    .backgroundColor('#f5f7fa')
                    .margin({ top: 12, bottom: 12 })

                    // Information Rows
                    this.InfoRow('设备 ID', this.selectedRecord.device_id)
                    this.InfoRow('作物种类', this.selectedRecord.crop_type === 'wheat' ? '小麦' : this.selectedRecord.crop_type === 'tea' ? '茶叶' : this.selectedRecord.crop_type)
                    this.InfoRow('病害名称', this.selectedRecord.disease_type)
                    this.InfoRow('识别置信度', `${(this.selectedRecord.confidence * 100).toFixed(1)}%`)
                    
                    Row() {
                      Text('严重程度')
                        .fontSize(14)
                        .fontColor('#7f8c8d')
                      Blank()
                      SeverityBadge({ severity: this.selectedRecord.severity })
                    }
                    .width('100%')
                    .padding({ top: 6, bottom: 6 })

                    this.InfoRow('检测时间', formatTimestamp(this.selectedRecord.timestamp))
                    this.InfoRow('联动风险级别', this.selectedRecord.linkage_risk_level || '无')
                    this.InfoRow('联动分析详情', this.selectedRecord.linkage_detail || '无')
                    this.InfoRow('已采取的措施', this.selectedRecord.action_taken || '无')
                  }
                  .width('100%')
                }
                .layoutWeight(1)
              }
              .width('90%')
              .height('75%')
              .backgroundColor('#ffffff')
              .borderRadius(16)
              .padding(16)
              .shadow({ radius: 24, color: 'rgba(0, 0, 0, 0.15)', offsetX: 0, offsetY: 12 })
              .onClick(() => {
                // Prevent click through to the closing overlay background
              })
            }
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0, 0, 0, 0.4)')
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .onClick(() => {
              this.isDetailOpen = false;
            })
          }
          .width('100%')
          .height('100%')
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#f5f7fa')
    }
    .title('病虫害记录')
  }

  @Builder
  FilterChip(label: string, value: string, isActive: boolean, onClick: (val: string) => void) {
    Text(label)
      .fontSize(12)
      .fontWeight(isActive ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(isActive ? '#ffffff' : '#34495e')
      .backgroundColor(isActive ? '#4cd9c0' : 'rgba(255, 255, 255, 0.5)')
      .border({ width: 1, color: isActive ? '#4cd9c0' : 'rgba(104, 159, 210, 0.15)' })
      .borderRadius(12)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .onClick(() => {
        onClick(value);
      })
  }

  @Builder
  InfoRow(label: string, val: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor('#7f8c8d')
      Blank()
      Text(val)
        .fontSize(14)
        .fontColor('#1e2a38')
        .fontWeight(FontWeight.Medium)
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
  }
}
