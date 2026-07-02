# 任务指令（v10）

## 动作
NEW

## 任务描述
在 server/ 目录下创建 Nginx 反向代理配置文件和 VPS 部署运维脚本，共 5 个文件：

### 产出清单

1. **server/nginx/farmeye.conf** - Nginx 反向代理配置，包含：
   - `upstream farmeye_api` 定义，指向 `api:8000`，keepalive 32
   - HTTP 80 监听 → HTTPS 301 重定向
   - HTTPS 443 ssl http2 服务端
   - SSL 证书路径 `/etc/nginx/ssl/fullchain.pem`、`/etc/nginx/ssl/privkey.pem`
   - SSL 协议 TLSv1.2/TLSv1.3，加密套件 `HIGH:!aNULL:!MD5`
   - SSL session cache `shared:SSL:10m`，timeout 10m
   - `location /api/` 反向代理至 farmeye_api，含 Host/X-Real-IP/X-Forwarded-For/X-Forwarded-Proto 头部转发
   - WebSocket 升级支持（Upgrade/Connection 头）
   - 超时：connect 30s、read 30s、send 30s
   - 缓冲：buffering on，buffer_size 4k，buffers 8 8k
   - `location /images/` 静态文件直连，alias `/usr/share/nginx/images/`，expires 7d，Cache-Control public immutable
   - `location /api/v1/health` 独立定义（access_log off）
   - 日志格式 `farmeye`，access_log 和 error_log 路径

2. **server/deploy/scripts/start.sh** - VPS 生产启动脚本：
   - `#!/bin/bash`，`set -euo pipefail`
   - 自动确定 SCRIPT_DIR 和 PROJECT_DIR
   - 使用 `docker compose -f docker-compose.yml -f docker-compose.prod.yml --profile production --compatibility up -d --build`
   - 启动后 wait 循环检查 health 端点（12 次，每次 5s），超时打印 api 日志
   - 最后输出 `docker compose ps`

3. **server/deploy/scripts/stop.sh** - VPS 生产停止脚本：
   - 默认行为：`docker compose ... stop` 停止服务保留容器
   - `--down`：停止并移除容器
   - `--volumes`：停止并移除容器和数据卷（含警告和 5s 延迟）

4. **server/deploy/scripts/restart.sh** - VPS 生产重启脚本：
   - 使用 `docker compose ... restart`

5. **server/deploy/scripts/backup.sh** - 数据库备份脚本：
   - `BACKUP_DIR=/opt/farmeye/backups/db`，`TIMESTAMP`，`DB_CONTAINER=farmeye-db`
   - 默认模式：每日 pg_dump plain SQL（--format=plain --no-owner）
   - `--full` 模式：每周 pg_dump custom format（--format=custom）
   - 检查数据库容器是否运行
   - docker cp 将备份文件复制到宿主机
   - find 清理过期备份（日备份 7 天，周备份 30 天）
   - 操作日志写入 `/opt/farmeye/backups/backup.log`

### 预期标准

- 所有文件内容与 `docs/2_vps-deployment.md` 中对应代码逐行一致
- 无敏感信息硬编码
- .sh 文件有可执行权限（chmod +x）
- 文件语法正确（Nginx config 可用 `nginx -t` 验证，shell 脚本可用 `bash -n` 验证）

## 选择理由

所有应用代码（API、Service、Model）、Docker 容器化配置（Dockerfile、docker-compose.yml、docker-compose.prod.yml、entrypoint.sh）和 API 单元测试（37 个用例）均已在 R1-R9 完成。此子任务是原任务描述 §6（开发工作流与部署辅助）的完整实现——Nginx 反向代理配置和 VPS 部署/停止/重启/备份脚本。这些文件不依赖其他模块，可以独立创建和验证。完成后，项目将具备从本地开发到 VPS 生产的完整配套。

## 任务上下文

参考设计文档：
- `docs/2_vps-deployment.md` §3.3 Nginx 反向代理配置（含 farmeye.conf 完整配置）
- `docs/2_vps-deployment.md` §3.3.2 Nginx 启用/禁用说明
- `docs/2_vps-deployment.md` §3.6.1 start.sh（VPS 生产启动脚本）
- `docs/2_vps-deployment.md` §3.6.2 stop.sh（VPS 生产停止脚本）
- `docs/2_vps-deployment.md` §3.6.3 restart.sh（VPS 生产重启脚本）
- `docs/2_vps-deployment.md` §2.3.2 backup.sh（数据库备份脚本）

已有产出上下文：
- server/ 下已有完整的 Docker 容器化配置：Dockerfile（多阶段 base/dev/prod）、docker-compose.yml（api+db+api-dev）、docker-compose.prod.yml（nginx+资源限制）、entrypoint.sh（两阶段迁移检测）
- server/ 下已有完整的 FastAPI 应用代码、测试代码（37 个 API 单元测试通过）
- server/nginx/ 和 server/deploy/scripts/ 目录当前均不存在，需从零创建

## 设计参考

Nginx farmeye.conf 完整配置见 `docs/2_vps-deployment.md` 第 1214-1293 行
start.sh 完整脚本见 `docs/2_vps-deployment.md` 第 1446-1488 行
stop.sh 完整脚本见 `docs/2_vps-deployment.md` 第 1493-1533 行
restart.sh 完整脚本见 `docs/2_vps-deployment.md` 第 1538-1553 行
backup.sh 完整脚本见 `docs/2_vps-deployment.md` 第 786-828 行
