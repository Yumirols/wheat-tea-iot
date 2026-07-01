# 任务指令（v1）

## 动作
NEW

## 任务描述
在 `server/` 目录下创建本地开发环境的基础配置文件。这些是项目最底层的"脚手架"文件，为后续所有开发工作奠定基础。

### 预期产出

以下 6 个文件必须全部创建：

#### 1. `server/requirements.txt` — 生产依赖
根据 `docs/2_vps-deployment.md` §1.2.1 的设计，包含：
- FastAPI & ASGI：fastapi~=0.115.0, uvicorn[standard]~=0.30.0, pydantic~=2.9.0, pydantic-settings~=2.5.0
- Database：psycopg2~=2.9.0（源码编译版，非 binary）, sqlalchemy~=2.0.0, alembic~=1.13.0
- HTTP Client：httpx~=0.27.0
- Image processing：Pillow~=10.4.0, python-multipart~=0.0.12
- Data export：openpyxl~=3.1.0
- Scheduling：apscheduler~=3.10.0

#### 2. `server/requirements-dev.txt` — 开发依赖
根据 `docs/2_vps-deployment.md` §1.2.2 的设计，包含：
- Testing：pytest~=8.3.0, pytest-asyncio~=0.24.0, httpx~=0.27.0
- Code quality：ruff~=0.6.0, mypy~=1.11.0
- Hot reload：watchfiles~=0.24.0

#### 3. `server/.env.dev.example` — 开发环境变量模板
根据 `docs/2_vps-deployment.md` §1.3.1 的设计，包含以下配置项（使用示例值）：
- DATABASE_URL（连接 localhost:5432）
- DB_USER, DB_NAME
- IOTDA_ENDPOINT, IOTDA_PROJECT_ID（占位值）
- ADVISORY_WINDOW_MINUTES
- DATA_RETENTION_SENSOR_DAYS, DATA_RETENTION_CONTROL_DAYS
- IMAGE_STORAGE_PATH（./images）
- API_KEYS（开发密钥示例）
- LOG_LEVEL=DEBUG

#### 4. `server/.env.prod.example` — 生产环境变量模板
根据 `docs/2_vps-deployment.md` §1.3.2 的设计：
- DATABASE_URL（连接 db:5432）
- DB_USER, DB_NAME
- IOTDA_ENDPOINT, IOTDA_PROJECT_ID（占位值）
- ADVISORY_WINDOW_MINUTES
- DATA_RETENTION_SENSOR_DAYS, DATA_RETENTION_CONTROL_DAYS
- IMAGE_STORAGE_PATH（/app/images）
- API_KEYS（多密钥示例）
- LOG_LEVEL=INFO
- 可选：HOST, PORT, WORKERS（作为注释保留）

#### 5. `server/.gitignore` — Git 忽略规则
根据 `docs/2_vps-deployment.md` §5.3.4 的设计：
- 环境变量文件（.env, .env.*，排除 .env.*.example）
- Python 缓存、虚拟环境、egg-info
- IDE 配置（.vscode/, .idea/）
- Docker 目录
- 日志、图片上传、备份目录
- 操作系统文件（.DS_Store, Thumbs.db）

#### 6. `server/.dockerignore` — Docker 构建上下文排除规则
根据 `docs/2_vps-deployment.md` §1.4.1 的设计：
- .env 文件（排除 .env.*.example）
- Python 缓存和虚拟环境
- .git/, .gitignore, README.md
- logs/, backups/

### 完成标准
- 所有 6 个文件创建完毕，内容与设计文档一致
- 使用 `~=` 版本约束说明符
- 配置文件内容正确，无硬编码敏感信息

## 选择理由
这是整个实现任务的第一个子任务，选择"基础配置文件"作为起点是因为：
1. requirements.txt 是所有 Python 代码的依赖基础
2. 环境变量模板定义了后续开发的配置规范
3. .gitignore 和 .dockerignore 确保版本控制和 Docker 构建的安全与整洁
4. 这些文件创建后，后续任务可以直接安装依赖、引用环境变量

## 任务上下文
- 项目根目录：E:\dev\wheat-tea-iot
- 工作目录：E:\dev\wheat-tea-iot\server\（当前为空）
- 设计参考文档：
  - `docs/2_vps-deployment.md` §1.2（依赖管理）、§1.3（环境变量模板）、§1.4.1（.dockerignore）、§5.3（环境变量管理）、§5.3.4（.gitignore）
  - `docs/local-development.md` §1（开发环境与依赖）

## 已有产出上下文
本任务为第一个子任务，工作目录中尚无已有产出。

## 注意事项
- .env.dev.example 和 .env.prod.example 使用"示例"后缀（.example），确保不会被 .gitignore 忽略
- 环境变量模板中的密钥值使用占位符（如 your_project_id_here），不包含真实凭据
- 所有 requirements 中的版本号使用 `~=` 兼容发布说明符
