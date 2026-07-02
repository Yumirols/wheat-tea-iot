# 产出审查报告（v7）

## 审查结果

REJECTED

## 逐维度审查

### 1. 任务完备性

**[通过]** 问题 1（.dockerignore）的三项子要求均已覆盖：§6.1 文件清单新增了 `.dockerignore`、§1.4.1 提供了完整的排除规则、§1.4 末尾增加了安全说明。

**[通过]** 问题 2（psycopg2-binary）的三项子要求均已覆盖：`requirements.txt` 中替换为 `psycopg2`、Dockerfile base 阶段新增了 `build-essential`/`python3-dev`/`libpq-dev` 三项编译依赖、修改处添加了注释说明。

**[通过]** 问题 3（两套 Schema 初始化机制）的四项子要求均已覆盖：§5.4.6 "初始基准迁移"子章节已新增、采纳了方案 A（alembic stamp head）并详细展开、init SQL 与 Alembic 的职责边界已明确区分、entrypoint.sh 已修改为优雅处理首次运行边界情况（alembic current 输出版本号、失败时输出警告而非退出）。

**[问题-一般]** 问题 4（cleanup_expired_data 异步定义但内部使用同步调用）未完整实现。迭代要求明确写明了"择一实现"（路径 A 或路径 B 二选一，使代码示例反映所选方案），但产出仅在函数 docstring 中添加了设计决策说明，并未实际修改代码示例——函数仍保留为 `async def` 且内部仍使用同步 `SessionLocal()` 调用。docstring 中"实际执行时应通过 asyncio.to_thread() 包装或将 APScheduler 中该 job 的 executor 切换为 ThreadPoolExecutor"的描述只是对问题的复述和修复方向的建议，并未体现已"择一实现"。修订说明（v7）中将此标注为"修改"，但实际上只完成了"添加注释说明"这一子要求，缺少了"择一实现"的主体要求。

**[通过]** 问题 5（测试用例 #40 预期结果矛盾）已修正为 `HTTP 503，status=degraded`。

**[通过]** 问题 6（SSL 端口映射与 Nginx 配置不匹配）已采纳路径 A：Nginx 配置补充了 `listen 443 ssl http2`、证书路径、SSL 协议与加密套件，新增了 §3.3.3 Certbot + Let's Encrypt 证书管理章节，UFW 规则注释已标注 443/tcp 用途。

**[通过]** 问题 7（--compatibility 依赖风险）的三项子要求均已覆盖：§3.5 增加了版本兼容性说明、§3.2.2 新增了 `docker inspect` 验证命令、替代方案（mem_limit/mem_reservation）已提及。

**[通过]** 问题 8a-8d（可选轻微问题）均已处理。

### 2. 质量达标性

**[通过]** 所有配置文件示例（Dockerfile、docker-compose.yml、nginx.conf、.gitignore、.dockerignore、entrypoint.sh 等）之间的引用关系一致，无明显的交叉矛盾。

**[问题-轻微]** §3.3.3 的 Certbot 续期 hook 脚本（第 1334 行）存在拼写笔误：`docker exec farmeye-ginx nginx -s reload` 中的容器名 `farmeye-ginx` 应为 `farmeye-nginx`（容器在 docker-compose.prod.yml 第 495 行定义为 `farmeye-nginx`）。该脚本若被运维人员直接复制使用，证书自动续期后的 Nginx 重载步骤将因容器名错误而失败。

**[通过]** 修订说明（v7）完整列出了 11 项修改，并与实际修改内容基本一致。

### 3. 正确性

**[通过]** 引用的所有外部资源（Docker Hub 镜像名、Certbot 命令、系统参数等）均为真实存在的工具和命令。

**[通过]** 技术判断（如 PostgreSQL 16 Alpine 镜像大小 ~200MB、KingbaseES 需要商业授权、`psycopg2` 从源码编译需要编译依赖等）与已知事实一致。

**[通过]** 文档内部的逻辑链自洽，无明显的自相矛盾。

## 修改要求（存在严重或一般问题时）

### 问题 1：问题 4（cleanup_expired_data 异步定义但内部使用同步调用）未按"择一实现"要求完成修改

- **问题**：迭代要求明确要求"择一实现"（路径 A 或路径 B），即选择一种方案并修改代码示例使之反映所选方案。产出仅在 docstring 中添加了设计决策说明，代码示例仍保持 `async def` + 同步 `SessionLocal()` 调用的原样，既未改为同步 `def`，也未使用 `asyncio.to_thread()`。
- **原因**：开发者若依据 §2.4 的代码示例直接编写实现代码，会照抄 `async def` + 同步调用的模式，引入阻塞事件循环的生产缺陷。docstring 中的设计决策说明仅为注释，无法阻止开发者直接复制 buggy 代码。
- **建议方向**：择一实现：
  - **路径 A**：将 `cleanup_expired_data` 改为普通同步 `def`，移除现有的设计决策注释（或改为说明为何选择同步路径）。
  - **路径 B**：保留 `async def`，将所有同步数据库操作（`SessionLocal()`、`db.execute()`、`db.commit()` 等）改为通过 `asyncio.to_thread()` 执行，并更新设计决策注释说明选择了此路径。
