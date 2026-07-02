#!/bin/bash
# FarmEye Guard — VPS 生产停止脚本
# 用法: ./stop.sh [--down] [--volumes]
#   --down     停止并移除容器（默认仅 stop）
#   --volumes  同时移除数据卷（危险！）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

if [ "${1:-}" = "--down" ]; then
    echo "[FarmEye] 停止并移除容器..."
    docker compose \
        -f docker-compose.yml \
        -f docker-compose.prod.yml \
        --profile production \
        down
    echo "[FarmEye] 容器已移除"
elif [ "${1:-}" = "--volumes" ]; then
    echo "[FarmEye] 警告: 将移除所有容器和数据卷！"
    echo "[FarmEye] 5 秒后执行，按 Ctrl+C 取消..."
    sleep 5
    docker compose \
        -f docker-compose.yml \
        -f docker-compose.prod.yml \
        --profile production \
        down --volumes
    echo "[FarmEye] 容器和数据卷已移除"
else
    echo "[FarmEye] 停止服务（保留容器）..."
    docker compose \
        -f docker-compose.yml \
        -f docker-compose.prod.yml \
        --profile production \
        stop
    echo "[FarmEye] 服务已停止"
fi
