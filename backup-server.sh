#!/bin/bash

# Конфигурация
BACKUP_DIR="/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="backup_$DATE.tar.gz"
LOG_FILE="$BACKUP_DIR/backup.log"

# Создаем директорию если не существует
mkdir -p "$BACKUP_DIR"

# Функция логирования
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "=== Starting backup ==="

# Проверка существования исходных директорий
log "Checking source directories..."
DIRECTORIES=("/etc/nginx" \
"/etc/prometheus" \
"/etc/grafana" \
"/home/safalkon" \
"/var/www" \
"/var/lib/prometheus" \
"/etc/default/prometheus*" \
)
EXISTING_DIRS=()

for dir in "${DIRECTORIES[@]}"; do
    if [ -d "$dir" ]; then
        EXISTING_DIRS+=("$dir")
        log "✓ Directory exists: $dir"
    else
        log "⚠ Directory not found: $dir"
    fi
done

# Проверяем есть ли что бэкапить
if [ ${#EXISTING_DIRS[@]} -eq 0 ]; then
    log "❌ ERROR: No existing directories to backup"
    exit 1
fi

# Создание бэкапа
log "Creating backup: $BACKUP_FILE"
if tar -czf "$BACKUP_DIR/$BACKUP_FILE" "${EXISTING_DIRS[@]}" 2>> "$LOG_FILE"; then
    BACKUP_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_FILE" | cut -f1)
    log "✓ Backup created successfully: $BACKUP_FILE ($BACKUP_SIZE)"
else
    log "❌ ERROR: Failed to create backup archive"
    exit 1
fi

# Ротация (храним 7 дней)
log "Cleaning up old backups..."
find "$BACKUP_DIR" -name "backup_*.tar.gz" -mtime +7 -delete -print | while read file; do
    log "🗑 Deleted: $(basename "$file")"
done

# Загрузка в Yandex Cloud (раскомментировать когда нужно)
#log "Uploading to Yandex Cloud..."
#if command -v yc &> /dev/null; then
#    if yc storage object upload \
#        --bucket-name my-backups \
#        --name "$BACKUP_FILE" \
#        --file "$BACKUP_DIR/$BACKUP_FILE" 2>> "$LOG_FILE"; then
#        log "✓ Uploaded to Yandex Cloud successfully"
#    else
#        log "⚠ WARNING: Failed to upload to Yandex Cloud"
#    fi
#else
#    log "⚠ WARNING: 'yc' command not found, skipping cloud upload"
#fi

log "=== Backup completed ==="