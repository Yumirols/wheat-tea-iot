# 任务计划

任务描述：实现本地开发、容器化与验证
工作目录：E:\dev\wheat-tea-iot\pdc\202607011640_local-dev-containerization

---

## R1 NEW 本地开发环境基础文件 [ID: T1]
任务：在 server/ 目录下创建本地开发环境的基础配置文件，包括：
  - server/requirements.txt（生产依赖）
  - server/requirements-dev.txt（开发依赖）
  - server/.env.dev.example（开发环境变量模板）
  - server/.env.prod.example（生产环境变量模板）
  - server/.gitignore（Git 忽略规则）
  - server/.dockerignore（Docker 构建上下文排除规则）

选择理由：这些是项目最底层的"脚手架"文件，所有后续工作（FastAPI 应用、Docker 容器化、测试）都依赖于此。先定义依赖和环境变量模板，可以确保后续开发有清晰的依赖管理基础和环境配置规范。

上下文：server/ 目录当前为空。所有配置文件和代码参考 `docs/2_vps-deployment.md` 第 1 章（本地开发环境配置与依赖管理）和第 5.3 节（环境变量管理）的设计方案。
