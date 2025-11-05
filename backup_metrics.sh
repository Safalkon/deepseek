#!/bin/bash
# Скрипт для мониторинга бэкапов

METRICS_DIR="/var/lib/prometheus/node-exporter"
METRICS_FILE="$METRICS_DIR/backup_metrics.prom"
BACKUP_DIR="/backups"
LOG_FILE="/backups/backup.log"

# Функция для записи метрик
write_metric() {
    echo "$1 $2" >> $TEMP_FILE
}

# Создаем временный файл для атомарной записи
TEMP_FILE=$(mktemp)

# Заголовки метрик
cat > $TEMP_FILE << 'EOF'
# HELP backup_status Backup status (1=ok, 0=failed)
# TYPE backup_status gauge
# HELP backup_age_seconds Backup age in seconds
# TYPE backup_age_seconds gauge
# HELP backup_size_bytes Backup size in bytes
# TYPE backup_size_bytes gauge
# HELP backup_files_count Number of backup files
# TYPE backup_files_count gauge
# HELP backup_last_success_timestamp Last successful backup timestamp
# TYPE backup_last_success_timestamp gauge
EOF

# Получаем информацию о последнем бэкапе
LATEST_BACKUP=$(find "$BACKUP_DIR" -name "backup_*.tar.gz" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -f2- -d" ")

if [[ -n "$LATEST_BACKUP" && -f "$LATEST_BACKUP" ]]; then
    BACKUP_TIMESTAMP=$(stat -c %Y "$LATEST_BACKUP")
    BACKUP_AGE=$(( $(date +%s) - BACKUP_TIMESTAMP ))
    BACKUP_SIZE=$(stat -c %s "$LATEST_BACKUP")
    
    # Проверяем валидность бэкапа (не старше 2 дней и не пустой)
    if [[ $BACKUP_AGE -lt 172800 && $BACKUP_SIZE -gt 1000 ]]; then
        BACKUP_STATUS=1
        LAST_SUCCESS_TIMESTAMP=$BACKUP_TIMESTAMP
    else
        BACKUP_STATUS=0
        LAST_SUCCESS_TIMESTAMP=0
    fi
    
    write_metric "backup_status $BACKUP_STATUS"
    write_metric "backup_age_seconds $BACKUP_AGE"
    write_metric "backup_size_bytes $BACKUP_SIZE"
    write_metric "backup_files_count $(find "$BACKUP_DIR" -name "backup_*.tar.gz" -type f | wc -l)"
    write_metric "backup_last_success_timestamp $LAST_SUCCESS_TIMESTAMP"
    
else
    # Нет бэкапов
    write_metric "backup_status 0"
    write_metric "backup_age_seconds -1"
    write_metric "backup_size_bytes -1"
    write_metric "backup_files_count 0"
    write_metric "backup_last_success_timestamp 0"
fi

# Атомарно заменяем файл метрик
mv "$TEMP_FILE" "$METRICS_FILE"

# Устанавливаем правильные права
chown prometheus:prometheus "$METRICS_FILE" 2>/dev/null || true
chmod 644 "$METRICS_FILE"