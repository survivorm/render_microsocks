#!/bin/sh

# Создаем простую директорию и файл для веб-сервера
mkdir -p /www/healthz
echo "OK" > /www/healthz/index.html

echo "Starting dummy HTTP server for health checks on port 8080..."
# Запускаем busybox httpd в фоне (-f заставляет его не демонизироваться)
# Он будет обслуживать файлы из /www
# Мы не указываем конкретный адрес, он будет слушать на 0.0.0.0
busybox httpd -f -p 8080 -h /www &

# Добавляем небольшую паузу, чтобы httpd успел запуститься (опционально)
sleep 2

echo "Starting microsocks on port 1080..."
# Запускаем microsocks на переднем плане (он будет основной программой)
# Используем exec, чтобы microsocks получил PID 1 в своей "ветке" и корректно обрабатывал сигналы завершения
exec /usr/local/bin/microsocks -p 1080 -u "$PROXY_USER" -P "$PROXY_PASSWORD"