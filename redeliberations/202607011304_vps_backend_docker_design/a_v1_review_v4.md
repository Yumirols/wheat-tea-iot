# 产出审查报告（v4）

## 审查结果

REJECTED

## 逐维度审查

### 1. 任务完备性

**[通过]** 五大任务板块（FastAPI 后端容器化、数据库方案、VPS 部署、测试方案、开发工作流）均有覆盖，产出物要求中的配置文件示例、测试用例表、1GB RAM 优化建议均已提供。

**[问题-一般]** 数据库方案以 PostgreSQL 16 Alpine 为主要推荐，KingbaseES 降级为可选方案 — 架构文档（`docs/1_system_architecture.md`）在部署拓扑（§1.2）、模块设计（§2.5）及仲裁结论（§6.1）中均明确指定 KingbaseES，任务要求也明确引用架构文档 §2.5 的 KingbaseES 定义。输出虽提供了 KingbaseES 切换说明，但主体配置（docker-compose、DDL 注释、健康检查命令、测试用例等）均以 PostgreSQL 为基线，未充分响应"KingbaseES 适配方案"这一任务要求。

### 2. 质量达标性

**[问题-严重]** 所有依赖文件（`requirements.txt` 和 `requirements-dev.txt`）使用 `==X.Y.x` 版本记号（如 `fastapi==0.115.x`），该格式不是有效的 pip 版本说明符。`pip install` 会报 "No matching distribution found" 错误，直接导致本地环境配置和 Docker 镜像构建失败。这是一个阻断性问题。

**[问题-一般]** 资源限制表（§3.5）声明 DB 内存限制为 256M，但 `docker-compose.prod.yml`（§1.5.2）将 DB 限制覆写为 384M。生产部署实际使用 384M，与文档表不一致，会造成内存规划误导。

**[问题-轻微]** 数据清理函数 `cleanup_expired_data()`（§2.4）声明为 `async def`，但函数体内全部使用同步 SQLAlchemy 操作（无 `await`），会在事件循环中阻塞。应改为普通 `def` 或使用异步数据库驱动。

**[问题-轻微]** VPS 内核参数配置（§3.1.3）中 `net.ipv4.tcp_tw_reuse=1` 在较新内核（5.x+）中已废弃/移除。Ubuntu 25.04（预期 kernel 6.x）上设置此参数可能导致 `sysctl --system` 报错。

### 3. 正确性

**[问题-一般]** Docker 容器测试用例 #4（§4.4.2）的预期验证命令为 `ksql -c 'SELECT 1'`。`ksql` 是 KingbaseES 的客户端工具，但输出的主要数据库推荐是 PostgreSQL 16（该镜像中不存在 `ksql`）。如果读者按 PostgreSQL 路径操作，该测试会因命令找不到而失败。

## 修改要求（存在严重或一般问题时）

### 问题 1：依赖文件使用无效 pip 版本记号

- **问题**：`requirements.txt` 和 `requirements-dev.txt` 中所有依赖均使用 `==X.Y.x` 格式，这不是 pip 支持的版本说明符。
- **原因**：读者直接使用这些文件时，pip install 会失败，阻断本地开发环境配置和 Docker 镜像构建。这是一个阻断性问题，会导致整套方案的可行性归零。
- **建议方向**：将所有 `==X.Y.x` 替换为有效的 pip 版本约束，例如 `~=0.115.0`（兼容发布）、`>=0.115.0,<0.116`（版本范围）、或指定确切版本号。建议在文档中说明这些是示例版本约束，读者可根据实际发布情况调整。

### 问题 2：数据库方案偏离架构文档对 KingbaseES 的明确要求

- **问题**：架构文档（§1.2、§2.5、§6.1 仲裁结论）明确指定 KingbaseES 为数据库，但输出以 PostgreSQL 16 为主线，KingbaseES 作为可选方案处理。
- **原因**：如果读者严格遵循架构文档要求使用 KingbaseES，则输出的 docker-compose 配置、健康检查命令、init 脚本注释、测试用例中的数据库操作命令均需按 KingbaseES 的差异逐一调整，而输出仅提供了概要的切换说明，未提供 KingbaseES 等效的完整配置。
- **建议方向**：二选一：(a) 以 KingbaseES 为主线重新提供完整配置（Docker 镜像拉取/导入方式、对应健康检查、连接串、资源调优参数），将 PostgreSQL 作为开发期替代方案；(b) 明确标注本次设计选择 PostgreSQL 的理由并补充 KingbaseES 的完整等效配置附录。

### 问题 3：容测试用例 #4 使用 KingbaseES 命令但主力方案是 PostgreSQL

- **问题**：测试用例 #4 的预期结果为 `` `ksql -c 'SELECT 1'` 执行成功 ``，但基于 PostgreSQL 16 的容器中不存在 `ksql` 命令。
- **原因**：读者按 PostgreSQL 路径运行 Docker 测试时，测试 #4 会失败。需要自行判断将 `ksql` 替换为 `pg_isready` 或 `psql`，增加不必要的排查成本。
- **建议方向**：将测试用例 #4 的预期结果改为与主力数据库方案一致。若以 PostgreSQL 为主，使用 `pg_isready`；若以 KingbaseES 为主，保留 `ksql` 但需确保所有配置也以 KingbaseES 为中心。

### 问题 4：资源限制表与生产覆写文件不一致

- **问题**：§3.5 的表格列出 DB 内存限制 256M，但 `docker-compose.prod.yml` 将 DB 限制覆写为 384M。生产部署按后者执行，导致文档与实际情况不符。
- **原因**：读者依赖 §3.5 表格做 VPS 内存规划（表格按 256MB 计算余量 424MB 给 OS），但实际部署后 DB 占用 384MB（比预期多 128MB），可能导致 OS 缓存不足或 swap 使用增加。
- **建议方向**：统一两处数值。如生产环境确实需要 384MB 给 DB，则更新 §3.5 表格和相关内存分配计算。
