#!/bin/bash

BACKUP_DIR="/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="backup_$DATE.tar.gz"

# Создание бэкапа
tar -czf $BACKUP_DIR/$BACKUP_FILE \
  /etc/nginx \
  /etc/prometheus \
  /etc/grafana \
  /home/safalkon \
  /var/www/

# Ротация (храним 7 дней)
find $BACKUP_DIR -name "backup_*.tar.gz" -mtime +7 -delete

# Загрузка в Yandex Cloud
#yc storage object upload \
#  --bucket-name my-backups \
#  --path $BACKUP_DIR/$BACKUP_FILE