# 第二和三部分：VPS 部署与上线发布详细方案

本方案对应系统部署规划的第二部分与第三部分（包含阶段六至阶段七），聚焦于 VPS 服务器的环境配置、Nginx 反向代理、安全网关防护，以及生产上线、代码同步、Alembic 版本印记对齐和华为云 IoTDA Webhook 的最终 HTTP 对接。

---

## 第二部分：VPS 服务器配置与安全网关 (阶段六)

本部分聚焦于 VPS 云端环境的初始化、代码部署同步、安全隔离以及反向代理网络拓扑配置。

### 6.1 VPS 系统环境初始化
推荐 VPS 配置为 Ubuntu 25.04 操作系统。初始化步骤如下：

```bash
# 1. 登录 VPS 并在 root 用户下创建运维专用的 farmeye 普通用户
ssh root@<VPS_IP>
adduser farmeye
usermod -aG sudo,docker farmeye

# 2. 安装 Docker & Docker Compose
sudo apt-get update
sudo apt-get install -y docker.io docker-compose-v2

# 3. 切换至 farmeye 用户配置 SSH 免密登录并测试
su - farmeye
mkdir -p ~/.ssh && chmod 700 ~/.ssh
# 将本地部署端的公钥写入 ~/.ssh/authorized_keys 中，并设置权限：
chmod 600 ~/.ssh/authorized_keys
```

### 6.2 代码与配置文件部署 (代码同步)
在启动任何容器服务之前，必须先将本地的代码和配置文件同步至 VPS，以获取 `docker-compose.yml` 及 Nginx 配置文件。

在**本地开发机**上执行以下命令，使用 `rsync` 将代码推送到 VPS：
```bash
# 本地终端执行
rsync -avz --delete \
    --exclude='.venv' --exclude='__pycache__' --exclude='.git' \
    --exclude='*.pyc' --exclude='.env.dev' --exclude='.env.prod' --exclude='.env' \
    server/ farmeye@<VPS_IP>:/opt/farmeye/
```

同步完成后，在 VPS 的 `/opt/farmeye/` 目录下创建并填写生产环境变量配置文件 `.env.prod`（**该文件不提交到 Git**）。

### 6.3 防火墙与安全隔离配置
为保障数据库与系统安全，需在 VPS 级别限制端口暴露规则：
*   **开放端口**：仅限 `22` (SSH)、`80` (HTTP) 端口对公网开放。
*   **限制端口**：[docker-compose.yml](file:///E:/dev/wheat-tea-iot/server/docker-compose.yml) 中的 `db` 容器绑定的 `5432` 端口，映射为 `127.0.0.1:5432:5432`（仅限本地环回访问），**严禁向公网开放 `5432`**。
*   **系统配置命令 (UFW)**：
    ```bash
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow 22/tcp
    sudo ufw allow 80/tcp
    sudo ufw enable
    ```

### 6.4 Nginx 反向代理配置 (纯 HTTP 网关)
Nginx 容器监听宿主机 `80` 端口，通过 Docker 内部桥接网络将请求分发给 API 服务：
*   **静态图片路由**：`/images/` 路径直接映射并由 Nginx 静态读取，无需经过 API 容器处理，提高并发效率。
*   **API 接口转发**：`/api/v1/` 路径反向代理转发给 `http://api:8000`。
*   **配置文件路径**：`/opt/farmeye/nginx/farmeye.conf`（对应本地的 [server/nginx/farmeye.conf](file:///E:/dev/wheat-tea-iot/server/nginx/farmeye.conf)）。

---

## 第三部分：生产上线与最终检验 (阶段七)

本部分聚焦于启动生产环境容器服务，并在公网环境下打通与华为云 IoTDA 的对接。

### 7.1 生产环境服务容器组启动
在 VPS 宿主机上，使用主编排文件与生产覆写文件合并启动容器组：
```bash
cd /opt/farmeye

# 合并主配置与生产覆写配置，启用 production 配置文件，在后台构建并启动容器组
docker compose \
    -f docker-compose.yml \
    -f docker-compose.prod.yml \
    --profile production \
    --compatibility \
    up -d --build
```
> **注意**：生产环境下添加了 `--compatibility` 参数，使 `deploy.resources.limits` 内存上限限制生效（限制数据库 384M 内存，API 服务 256M 内存，Nginx 服务 64M 内存，符合 1GB VPS 物理内存运行约束）。

### 7.2 Alembic 数据库迁移版本印记对齐
首次启动时，PostgreSQL 容器已自动载入了 `init/01_create_tables.sql` 的完整建表结构，此时数据库结构最新，但 Alembic 未记录迁移印记。
在容器拉起并保持运行后，必须手动在 VPS 宿主机运行 `stamp` 命令建立最初的版本对齐印记：
```bash
docker compose exec api alembic stamp head
```
此后，所有新增表结构或字段修改都将走标准的 `alembic upgrade head` 自动执行增量迁移。

### 7.3 华为云 IoTDA Webhook 与端到端对接
由于采用纯 HTTP 对接，在华为云设备接入（IoTDA）控制台的“数据流转规则”中，配置 HTTP 方式 of Webhook 推送地址：
*   将 `service_id = 'farmeye_env'` 推送至：`http://<VPS_IP_或_您的域名>/api/v1/iotda/properties/report`
*   将 `service_id = 'farmeye_ai'` 推送至：`http://<VPS_IP_或_您的域名>/api/v1/iotda/ai/report`
*   将命令应答推送至：`http://<VPS_IP_或_您的域名>/api/v1/iotda/cmd/response`

---

## 自动化运维与备份机制

### 8.1 一键运维控制脚本
在 VPS 上使用脚本完成服务的快速启停：
*   **启动脚本** ([deploy/scripts/start.sh](file:///E:/dev/wheat-tea-iot/deploy/scripts/start.sh))：合并加载配置文件并以后台模式启动。
*   **停止脚本** ([deploy/scripts/stop.sh](file:///E:/dev/wheat-tea-iot/deploy/scripts/stop.sh))：优雅地停止所有后台服务。

### 8.2 数据备份脚本
编写自动定时备份脚本 [backup.sh](file:///E:/dev/wheat-tea-iot/deploy/scripts/backup.sh)，通过 crontab 挂载，每日凌晨 3:00 自动执行：
```bash
# 每日备份执行命令示例
docker exec -t farmeye-db pg_dump -U farmeye -d farmeye_db | gzip > /opt/farmeye/backups/db/farmeye_db_${TIMESTAMP}.sql.gz
```
脚本会自动保留最近 7 天内的物理备份，并删除过期备份以节省 VPS 存储空间。
