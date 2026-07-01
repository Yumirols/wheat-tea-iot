# 质询：b_v1_diag_v1.md

**审查维度**: 逻辑完整性 — 改进建议的内部完备性

---

## 质询点：H2（生产依赖使用 `psycopg2-binary`）的改进建议不可直接执行

**位置**: b_v1_diag_v1.md 第 29-46 行

**问题描述**:

诊断报告正确识别了 H2 问题（`psycopg2-binary` 不推荐用于生产环境），但其给出的改进建议第 2 项不完整，导致按建议修改后 Docker 构建直接失败。

报告建议在 Dockerfile `base` 阶段的 `apt-get install` 中仅添加 `libpq-dev`。但 `psycopg2` 从源码构建（将 `psycopg2-binary` 替换为 `psycopg2` 后的必然行为）需要三组编译依赖，而非仅 `libpq-dev` 一组：

1. **`libpq-dev`** — 报告已提及，提供 `pg_config` 工具及 libpq 头文件。
2. **C 编译器**（`gcc`/`build-essential`）— 报告未提及。`psycopg2` 的 C 扩展模块（`psycopg/psycopgmodule.c`）需要 C 编译器编译。当前 Dockerfile `base` 阶段仅安装 `python3`、`python3-venv`、`python3-pip`、`curl`、`ca-certificates`，这些软件包均不依赖 `gcc`。缺少 C 编译器时 `pip install psycopg2` 报错 `gcc: command not found`。
3. **`python3-dev`**（提供 `Python.h` 头文件）— 报告未提及。`psycopg2` 构建需要 Python 头文件。Ubuntu 25.04 的 `python3` 包不包括 `Python.h`；该头文件由独立的 `python3-dev` 包提供。无 `python3-dev` 时构建报错 `Python.h: No such file or directory`。

**验证方法**:
- 验证原始设计文档 §1.4 Dockerfile（第 217-242 行）：`base` 阶段的 `apt-get install` 列表中无 `gcc` 或 `build-essential`，无 `python3-dev`。
- 验证 `apt-get` 依赖链：`python3`、`python3-venv`、`python3-pip` 在 Ubuntu 25.04 上不传递依赖 `gcc`。
- 验证 `psycopg2` 构建流程：PyPI 上的 `psycopg2` 包（2.9.x）不发布 `manylinux` wheel，仅提供源码分发包（sdist），`pip install` 时必须在目标平台上编译。

**影响**:
如果按诊断报告的建议修改（替换 `psycopg2-binary` → `psycopg2` + 仅添加 `libpq-dev`），`docker compose up -d --build` 将在 `pip install -r requirements.txt` 步骤失败，构建退出。开发者需自行排查为何编译失败，额外增加 `build-essential` 和 `python3-dev` 后才能继续。这直接违背了"执行模式 — 审查通用执行产出的可用性"的审查目标，因为改进建议本身不具有直接可执行性。

---

## 诊断

**LOCATED**: 除上述 H2 建议不完整外，其他所有质量问题（H1、H3、M1-M4、L1-L4）均已准确识别，证据充分，建议可行。

**CHALLENGED**: H2 改进建议第 2 项缺少 C 编译器（`gcc`/`build-essential`）和 Python 头文件（`python3-dev`）两项编译依赖，导致建议不可直接执行，属于逻辑完整性维度的缺陷。

CHALLENGED:E:\dev\wheat-tea-iot\redeliberations\202607011304_vps_backend_docker_design\b_v1_challenge_v1.md
