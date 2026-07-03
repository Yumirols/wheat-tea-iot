#!/bin/bash
# FarmEye Guard — VPS 生产启动脚本
# 用法: ./start.sh
#
# 说明：使用 docker-compose.yml 主文件 + docker-compose.prod.yml
# 生产覆写文件合并启动，确保 Nginx 服务和生产覆写配置生效。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

cd "$PROJECT_DIR"

echo "[FarmEye] 启动服务..."

# 合并主文件 + 生产覆写文件启动
docker compose \
    -f docker-compose.yml \
    -f docker-compose.prod.yml \
    --profile production \
    --compatibility \
    up -d --build

echo "[FarmEye] 服务启动完成"

# 等待健康检查
echo "[FarmEye] 等待 API 健康检查..."
for i in $(seq 1 12); do
    if curl -s http://localhost:8000/api/v1/health | grep -q '"status":"healthy"'; then
        echo "[FarmEye] API 服务健康"
        break
    fi
    if [ "$i" -eq 12 ]; then
        echo "[FarmEye] 警告: API 健康检查超时，请查看日志"
        docker compose logs api --tail=20
    fi
    sleep 5
done

docker compose ps
echo "[FarmEye] 部署完成"
