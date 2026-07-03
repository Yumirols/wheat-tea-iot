/**
 * 分页列表容器。
 *
 * - 接收父组件提供的 `@Builder` 渲染模板（`renderItem`）作为 `@BuilderParam`
 * - 滚动到末尾前 5 条时自动触发下一页加载
 * - `aboutToAppear` 时加载第 1 页（`currentPage` 从 1 开始，与后端分页约定一致）
 * - 失败时 `console.error` 记录，已有数据保留
 *
 * 父组件约束：
 * - `renderItem` 必须用 `@Builder` 修饰方法后传入（ArkUI 严格模式要求
 *   `@BuilderParam` 接收 `@Builder` 引用，不能是普通函数）
 * - 父组件调用示例：
 *   ```typescript
 *   @Builder private renderItem(item: DiseaseRecord, index: number): void {
 *     ListItem() { ... }
 *   }
 *   PaginatedList<DiseaseRecord>({
 *     renderItem: this.renderItem,
 *     loadPage: (page: number) => DiseaseService.getList(page, this.pageSize)
 *   });
 *   ```
 *
 * 注意：ArkTS 泛型 `@BuilderParam` 在严格模式下可能有限制；如遭遇编译错误，
 * 回退方案：使用 `as any` 转型或拆分为非泛型具体类型组件。
 *
 * Props：
 * - `@BuilderParam renderItem: (item: T, index: number) => void` —— 必填
 * - `loadPage: (page: number) => Promise<PaginatedData<T>>` —— 必填
 * - `pageSize: number = 20` —— 每页条数（本组件不直接使用，供父组件参考）
 */

import { PaginatedData } from '../common/models';

@Component
struct PaginatedList<T> {
  @BuilderParam renderItem: (item: T, index: number) => void;
  @Prop loadPage: (page: number) => Promise<PaginatedData<T>>;
  @Prop pageSize: number = 20;
  @State private records: T[] = [];
  @State private currentPage: number = 1;
  @State private hasMore: boolean = true;
  @State private isLoading: boolean = false;

  aboutToAppear(): void {
    this.loadNextPage();
  }

  build() {
    List() {
      ForEach(this.records, (item: T, index: number) => {
        this.renderItem(item, index);
      })
    }
    .onScrollIndex((end: number) => {
      if (end >= this.records.length - 5 && this.hasMore && !this.isLoading) {
        this.loadNextPage();
      }
    })
  }

  /**
   * 加载下一页：调用 `loadPage(currentPage)` 后追加到 `records`，推进 `currentPage`，
   * 根据总数判定是否还有更多。
   */
  private async loadNextPage(): Promise<void> {
    this.isLoading = true;
    try {
      const data: PaginatedData<T> = await this.loadPage(this.currentPage);
      this.records = this.records.concat(data.records);
      this.hasMore = this.records.length < data.pagination.total;
      this.currentPage++;
    } catch (err: unknown) {
      console.error('PaginatedList load error', JSON.stringify(err));
    } finally {
      this.isLoading = false;
    }
  }
}

export { PaginatedList };