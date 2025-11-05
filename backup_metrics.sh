#!/bin/bash

METRICS_DIR="/var/lib/prometheus/node-exporter"
METRICS_FILE="$METRICS_DIR/backup_metrics.prom"
BACKUP_DIR="/backups"

# Создаем временный файл
TEMP_FILE=$(mktemp)

# Получаем информацию о последнем бэкапе
LATEST_BACKUP=$(find "$BACKUP_DIR" -name "backup_*.tar.gz" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -f2- -d" ")

# Создаем файл метрик
{
    echo "# HELP backup_status Backup status (1=ok, 0=failed)"
    echo "# TYPE backup_status gauge"
    echo "# HELP backup_age_seconds Backup age in seconds" 
    echo "# TYPE backup_age_seconds gauge"
    echo "# HELP backup_size_bytes Backup size in bytes"
    echo "# TYPE backup_size_bytes gauge"
    echo "# HELP backup_files_count Number of backup files"
    echo "# TYPE backup_files_count gauge"
    echo "# HELP backup_last_success_timestamp Last successful backup timestamp"
    echo "# TYPE backup_last_success_timestamp gauge"
} > "$TEMP_FILE"

if [[ -n "$LATEST_BACKUP" && -f "$LATEST_BACKUP" ]]; then
    BACKUP_TIMESTAMP=$(stat -c %Y "$LATEST_BACKUP")
    BACKUP_AGE=$(( $(date +%s) - BACKUP_TIMESTAMP ))
    BACKUP_SIZE=$(stat -c %s "$LATEST_BACKUP")
    
    # Проверяем валидность бэкапа
    if [[ $BACKUP_AGE -lt 172800 && $BACKUP_SIZE -gt 1000 ]]; then
        BACKUP_STATUS=1
        LAST_SUCCESS_TIMESTAMP=$BACKUP_TIMESTAMP
    else
        BACKUP_STATUS=0
        LAST_SUCCESS_TIMESTAMP=0
    fi
    
    {
        echo "backup_status $BACKUP_STATUS"
        echo "backup_age_seconds $BACKUP_AGE"
        echo "backup_size_bytes $BACKUP_SIZE"
        echo "backup_files_count $(find "$BACKUP_DIR" -name "backup_*.tar.gz" -type f | wc -l)"
        echo "backup_last_success_timestamp $LAST_SUCCESS_TIMESTAMP"
    } >> "$TEMP_FILE"
else
    {
        echo "backup_status 0"
        echo "backup_age_seconds -1"
        echo "backup_size_bytes -1"
        echo "backup_files_count 0"
        echo "backup_last_success_timestamp 0"
    } >> "$TEMP_FILE"
fi

# Атомарно заменяем файл метрик
mv "$TEMP_FILE" "$METRICS_FILE"

# Устанавливаем правильные права
chown prometheus:prometheus "$METRICS_FILE" 2>/dev/null || true
chmod 644 "$METRICS_FILE"