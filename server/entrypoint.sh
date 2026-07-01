#!/bin/bash
set -e

echo "[FarmEye] 执行数据库迁移..."

# 检测 Alembic 版本状态
CURRENT_OUTPUT=$(alembic current 2>&1 || true)

if echo "$CURRENT_OUTPUT" | grep -qE '^[a-f0-9]{12}'; then
    echo "[FarmEye] 检测到已有迁移版本记录"
    STRICT_MIGRATION=true
else
    echo "[FarmEye] 未检测到迁移版本记录（首次部署或无版本信息）"
    STRICT_MIGRATION=false
fi

if alembic upgrade head 2>&1; then
    echo "[FarmEye] 数据库迁移成功"
else
    if [ "$STRICT_MIGRATION" = "true" ]; then
        echo "[FarmEye] 错误: 数据库迁移失败（已有版本记录但升级出错）" >&2
        echo "[FarmEye] 请检查迁移脚本或数据库连接，修复后重新启动容器。" >&2
        echo "[FarmEye] 常见原因：迁移脚本 SQL 语法错误、数据库连接中断、迁移版本历史冲突" >&2
        exit 1
    else
        echo "[FarmEye] 警告: 数据库迁移未完成 - 可能是首次部署，"
        echo "        init SQL 已完成基线初始化。"
        echo "        请部署后执行: alembic stamp head"
    fi
fi

echo "[FarmEye] 启动 API 服务..."
exec "$@"
