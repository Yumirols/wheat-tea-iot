# 产出审查报告（v2）

## 审查结果

REJECTED

## 逐维度审查

### 1. 任务完备性

**[通过]** 产出覆盖了任务描述中的所有 5 个主要领域：Python API 后端容器化、KingbaseES 适配、VPS 部署方案、测试方案、开发工作流。

**[通过]** 产出提供了完整的配置文件示例（Dockerfile、docker-compose.yml、nginx.conf、环境变量模板等），并在附录中汇总了文件清单和快速部署命令。

**[通过]** 测试方案列出了具体的测试用例名称和预期结果（48 个 API 测试 + 12 个数据库集成测试 + 10 个 Docker 测试 + 6 个端到端测试 + 7 个性能场景），覆盖了任务要求的各个测试维度。

**[通过]** 所有配置和脚本明确针对 Digital Ocean Ubuntu 25.04 VPS 设计，资源限制配置适配 1GB RAM 约束。

### 2. 质量达标性

**[通过]** 产出的组织结构清晰，按 5 个主要领域分章节，附有目录和附录文件清单，便于查阅和使用。

**[通过]** 各项技术方案内部逻辑自洽：API 端点设计、数据库表结构、Docker 配置、测试用例之间的引用关系一致。

**[问题-一般]** deploy/scripts/start.sh 启动脚本与 §3.2.3 的生产覆写要求不一致。§3.2.3 明确了生产环境部署需合并 docker-compose.prod.yml 覆写文件启动（`docker compose -f docker-compose.yml -f /opt/farmeye/docker-compose.prod.yml up -d --build`），但 §3.6.1 的 start.sh 和 §5.1.3 的部署步骤仅使用 `docker compose --compatibility up -d --build`，未引入生产覆写文件。这导致两个后果：(1) Nginx 服务（仅在 docker-compose.prod.yml 中定义）不会启动；(2) 生产覆写中的 restart 策略等配置不生效。参考 §3.6.1:1617-1657、§5.1.3:2314-2324。

**[问题-一般]** 产出 §4.5.2 将 pytest 钩子函数（`pytest_addoption`、`pytest_configure`、`pytest_collection_modifyitems`）定义在测试文件 `test_e2e.py` 中。pytest 的钩子发现机制仅扫描 `conftest.py` 和注册的插件，不会从 `test_*.py` 文件中自动发现这些引导阶段（bootstrap）钩子。按产出设计的写法，`--run-e2e` 命令行参数将无法注册，端到端测试的跳过逻辑不会执行。参考 §4.5.2:1977-1999。

### 3. 正确性

**[通过]** Dockerfile 多阶段构建策略（base/dev/prod）设计合理，Ubuntu 25.04 基础镜像与 VPS 操作系统一致。

**[通过]** KingbaseES 镜像适配方案提供了三种可行选项，对 VPS 1GB RAM 约束下的内存分配（KingbaseES 384MB + API 256MB + OS 360MB）合理且有具体参数。

**[通过]** 资源限制配置中 `deploy.resources.limits.memory` 与内存分配方案一致，整体占用在 1GB 范围内。

**[问题-一般]** 同质量达标性部分所述的第 1、2 个问题，均为技术正确性问题。

## 修改要求（存在严重或一般问题时）

### 问题 1：start.sh 及部署步骤未使用生产覆写文件

- **问题**：`deploy/scripts/start.sh`（§3.6.1）和 §5.1.3 的 VPS 部署步骤使用 `docker compose --compatibility up -d --build`，未引用 `docker-compose.prod.yml` 覆写文件。而 §3.2.3 明确要求合并覆写文件启动。
- **原因**：后续实施者按 start.sh 或 §5.1.3 部署生产环境时，Nginx 不会启动，生产环境专用配置不会生效。多个章节之间的不一致会导致实施者困惑。
- **建议方向**：统一部署命令。方案 A：将 Nginx 服务和生产覆写配置合并入主 `docker-compose.yml`，取消覆写文件。方案 B：更新 start.sh 和 §5.1.3 中的命令为 `docker compose -f docker-compose.yml -f /opt/farmeye/docker-compose.prod.yml --compatibility up -d --build`，并确保路径一致性。

### 问题 2：pytest 钩子定义在测试文件中无法被发现

- **问题**：§4.5.2 的 `test_e2e.py` 代码中 `pytest_addoption`、`pytest_configure`、`pytest_collection_modifyitems` 三个钩子函数定义在测试文件内。pytest 不会从 `test_*.py` 文件中发现引导阶段钩子，这些函数必须位于 `conftest.py` 或注册的插件中。
- **原因**：实施者按产出代码实现后，`pytest --run-e2e` 会因无法识别参数而报错，端到端测试的跳过机制失效。这会降低测试方案的可信度。
- **建议方向**：将这三个钩子函数移至 `server/tests/conftest.py`（§4.1.3 中已有该文件设计），或者移除钩子函数、改用 `pytest -m e2e` 的 marker 筛选机制（需在 pytest.ini 中注册 marker）。
