#!/bin/bash
# FarmEye Guard — VPS 生产重启脚本
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

cd "$PROJECT_DIR"
echo "[FarmEye] 重启服务..."
docker compose \
    -f docker-compose.yml \
    -f docker-compose.prod.yml \
    --profile production \
    restart
echo "[FarmEye] 服务已重启"
