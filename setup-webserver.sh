#!/bin/bash

# Функция проверки прав администратора
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Ошибка: Запустите скрипт с sudo!"
        exit 1
    fi
}

# Функция проверки статуса nginx
check_nginx_status() {
    echo "Проверка статуса Nginx..."
    if systemctl is-enabled nginx > /dev/null 2>&1; then
        echo "Nginx включен в автозагрузку"
    else
        echo "Nginx не включен в автозагрузку"
    fi
    
    if systemctl is-active nginx > /dev/null 2>&1; then
        echo "Nginx работает"
    else
        echo "Nginx не запущен"
    fi
}

# Функция обновления системы
update_system() {
    echo "Обновление списка пакетов..."
    if ! apt update; then
        echo "Ошибка: apt update завершился с ошибкой"
        exit 1
    fi

    echo "Обновление системы..."
    if apt upgrade -y; then
        echo "Обновление системы завершено успешно!"
    else
        echo "Ошибка: apt upgrade завершился с ошибкой"
        exit 1
    fi
}

# Функция установки nginx
install_nginx() {
    echo "Установка Nginx..."
    if ! apt install nginx -y; then
        echo "Ошибка установки Nginx"
        exit 1
    else
        echo "Nginx успешно установлен"
    fi
}

# Функция замены содержимого index.html
update_index_html() {
    local html_file="/var/www/html/index.html"
    local backup_file="/var/www/html/index.html.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Проверка существования директории
    if [ ! -d "/var/www/html" ]; then
        echo "Создание директории /var/www/html..."
        mkdir -p "/var/www/html" || {
            echo "Ошибка: Не удалось создать директорию /var/www/html"
            return 1
        }
    fi
    
    # Создание бэкапа если файл существует
    if [ -f "$html_file" ]; then
        if cp "$html_file" "$backup_file"; then
            echo "Бэкап создан: $backup_file"
        else
            echo "Ошибка при создании бэкапа"
            return 1
        fi
    else
        echo "Создание нового файла index.html..."
    fi
    
    # Новое содержимое
    cat > "$html_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Welcome to nginx!</title>
    <style>
        html { 
            color-scheme: light dark; 
        }
        body { 
            width: 35em; 
            margin: 0 auto;
            font-family: Tahoma, Verdana, Arial, sans-serif; 
        }
    </style>
</head>
<body>
    <h1>Welcome to nginx!</h1>
    <p>Стенд для курса Linux Admin. Задание #002 выполнено!</p>
</body>
</html>
EOF

    if [ $? -eq 0 ]; then
        echo "Файл index.html успешно обновлен"
        # Установка правильных прав
        chown www-data:www-data "$html_file" 2>/dev/null || true
        chmod 644 "$html_file"
        return 0
    else
        echo "Ошибка при обновлении index.html"
        # Восстановление из бэкапа если он существует
        if [ -f "$backup_file" ]; then
            cp "$backup_file" "$html_file"
            echo "Восстановлен файл из бэкапа"
        fi
        return 1
    fi
}

# Функция запуска и включения nginx
enable_nginx() {
    echo "Запуск и включение Nginx..."
    systemctl enable nginx --now 2>/dev/null || {
        systemctl start nginx
        systemctl enable nginx
    }
    
    # Небольшая задержка для применения изменений
    sleep 2
}

# Главная функция
main() {
    echo "=== Начало работы скрипта ==="
    
    # Проверка прав
    check_root
    
    # Обновление системы
    update_system
    
    # Установка nginx
    install_nginx
    
    # Запуск и включение nginx
    enable_nginx
    
    # Обновление index.html
    update_index_html
    
    # Проверка статуса nginx
    check_nginx_status
    
    echo "=== Скрипт завершил работу ==="
}

# Вызов главной функции
main