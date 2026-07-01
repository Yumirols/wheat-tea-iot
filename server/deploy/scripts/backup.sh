#!/bin/bash
# FarmEye Guard — 数据库备份脚本
# 用法: ./backup.sh                    # 每日增量
#       ./backup.sh --full             # 全量（每周）

BACKUP_DIR="/opt/farmeye/backups/db"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DB_CONTAINER="farmeye-db"
RETENTION_DAYS=7

mkdir -p "$BACKUP_DIR"

# 检查数据库容器是否运行
if ! docker ps --format '{{.Names}}' | grep -q "^${DB_CONTAINER}$"; then
    echo "[ERROR] 数据库容器 ${DB_CONTAINER} 未运行，备份中止"
    exit 1
fi

if [ "$1" = "--full" ]; then
    docker exec "$DB_CONTAINER" pg_dump \
        --format=custom \
        --file="/tmp/farmeye_full_${TIMESTAMP}.dump" \
        -U farmeye farmeye_db
    docker cp "${DB_CONTAINER}:/tmp/farmeye_full_${TIMESTAMP}.dump" \
        "${BACKUP_DIR}/weekly/"
    RETENTION_DAYS=30
else
    docker exec "$DB_CONTAINER" pg_dump \
        --format=plain \
        --no-owner \
        --file="/tmp/farmeye_daily_${TIMESTAMP}.sql" \
        -U farmeye farmeye_db
    docker cp "${DB_CONTAINER}:/tmp/farmeye_daily_${TIMESTAMP}.sql" \
        "${BACKUP_DIR}/"
fi

# 清理过期备份
find "$BACKUP_DIR" -name "farmeye_daily_*.sql" -mtime +${RETENTION_DAYS} -delete
find "$BACKUP_DIR/weekly" -name "farmeye_full_*.dump" -mtime +30 -delete

echo "[$(date)] Backup completed: farmeye_${TIMESTAMP}" >> /opt/farmeye/backups/backup.log
