# 产出审查报告（v1）

## 审查结果

REJECTED

## 逐维度审查

### 1. 任务完备性

**[通过]** 5 大任务领域（Python API 后端、KingbaseES 数据库、VPS 部署方案、测试方案、开发工作流）全部覆盖，无遗漏。

**[通过]** 产出物要求（完整的配置文件示例、具体测试用例名称和预期结果、Ubuntu 25.04 可直接运行的脚本、1GB RAM 资源约束考虑）全部满足。

**[通过]** 附录 6.1 给出了完整的文件清单，与架构文档 §5.1 定义的 server/ 目录结构一致，且在此基础上对 tests/ 目录做了详细展开。测试方案列出了 70 个+ 具体测试用例及其预期结果，覆盖了 API 接口、数据库集成、Docker 容器、端到端、性能测试各层次。

### 2. 质量达标性

**[通过]** 方案结构清晰，采用分层分段写法，每段均含可直接使用的代码/配置示例。章节组织合理，从后端开发到数据库再到部署和测试，递进关系明确。

**[通过]** 测试方案设计完整，覆盖了正常路径、异常路径、边界条件（如测试用例 3 幂等性、15 分页边界、45 数据库断连等）。

**[问题-一般]** **Docker APT 源使用 Ubuntu 24.04 "noble" 代号，而非 Ubuntu 25.04 "plucky" 代号。** 产出明确标注 VPS 操作系统为 Ubuntu 25.04，但在 §3.1.2 Docker 安装中使用 `echo "deb ... noble stable"` 添加 APT 源。"noble" 是 Ubuntu 24.04 的代号，Ubuntu 25.04 的代号为 "plucky"。在 Ubuntu 25.04 上使用 "noble" 的 Docker APT 源可能导致仓库元数据不匹配、`apt-get update` 失败，或安装不兼容的软件包。影响：直接按 §3.1.2 步骤操作的开发者在 Ubuntu 25.04 VPS 上会遇到 Docker 安装失败或潜在依赖冲突。

**[问题-轻微]** **声称 "Python 3.12.x 与 Ubuntu 25.04 默认 Python 版本对齐" 不准确。** Ubuntu 25.04 (Plucky Puffin) 默认安装 Python 3.13，而非 3.12。Python 3.12 可通过 `apt install python3.12` 额外安装，但并非"默认版本"。该表述会误导开发者。

**[问题-轻微]** **`.dockerignore` 中存在重复条目。** `.venv/` 和 `.venv_old/` 各出现了两次，虽不影响功能但显得草率。

**[问题-轻微]** **`conftest.py` 中测试数据库文件清理缺乏防御性处理。** `os.remove("./data/test_farmeye.db")` 在 `test_engine session` 级别 fixture 的 teardown 中执行，若 `create_all` 失败导致文件未创建，`os.remove` 将抛出 `FileNotFoundError`，可能掩盖真正的测试失败原因。

### 3. 正确性

**[通过]** Dockerfile、docker-compose.yml、Nginx 配置、初始化 SQL 脚本等所有配置示例在语法上正确，与环境变量、端口映射、Volume 挂载等逻辑一致。

**[通过]** 所有 API 测试用例的预期结果与架构文档 §4 定义的接口规范一致（响应结构、状态码、错误码）。

**[通过]** 数据保留与清理策略正确实现了要求（sensor_snapshot 30 天、control_logs 90 天），其 APScheduler 实现逻辑自洽。

**[问题-轻微]** **启动迁移代码在异步 startup handler 中执行同步 Alembic 调用。** §5.5.4 中 `startup_event` 被声明为 `async def`，但内部调用了同步的 `run_migrations()`（含 `command.upgrade`）。这会阻塞事件循环。虽在实践中迁移时间很短（仅 5 张表），但这是不规范的异步编程模式，若后续迁移脚本增多可能造成启动超时。

## 修改要求（存在严重或一般问题时）

- **问题**：Docker APT 源使用 Ubuntu 24.04 (noble) 代号而非 Ubuntu 25.04 (plucky) 代号。
- **原因**：在 Ubuntu 25.04 上执行 `echo "deb ... noble stable" >> /etc/apt/sources.list.d/docker.list && sudo apt-get update` 会导致仓库元数据不匹配——Docker 的 noble 仓库是针对 Ubuntu 24.04 libc/glibc 版本构建的，在 Ubuntu 25.04 上可能出现依赖冲突。直接按文档操作的开发者会因 Docker 安装失败而受阻，无法继续进行后续的 docker-compose 部署和测试。
- **建议方向**：将 `noble` 替换为 `plucky`（Ubuntu 25.04 的正确代号），或使用 `$(lsb_release -cs)` 动态检测。同时保持 §6.2 中的 `curl -fsSL https://get.docker.com | sudo sh` 作为推荐的便捷安装方式（该脚本会自动检测 OS）。另外，建议在文档中增加说明：若 Docker 官方尚未发布 plucky 源，可回退到 noble 源并添加 `--allow-releaseinfo-change` 参数，并注明风险。
