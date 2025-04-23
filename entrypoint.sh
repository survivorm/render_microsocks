#!/bin/sh

# Создаем простую директорию и файл для веб-сервера
mkdir -p /www/healthz
echo "OK" > /www/healthz/index.html

echo "Starting darkhttpd server for health checks on port 8080..."
# Запускаем darkhttpd в фоне
# --port 8080 : указываем порт
# --chroot /www : указываем корневую папку для файлов
# --daemon : запускаем в фоне (daemonize)
# --log /dev/stdout : пишем логи в stdout (может потребоваться или нет, попробуем без него сначала)
# Важно: darkhttpd по умолчанию слушает на 0.0.0.0
# Используем --no-daemon чтобы он оставался на переднем плане, если запущен не через &
# Поэтому запускаем через & чтобы он ушел в фон
darkhttpd /www --port 8080 &


# Добавляем небольшую паузу, чтобы httpd успел запуститься (опционально)
sleep 2

echo "Starting microsocks on port 1080..."
# Запускаем microsocks на переднем плане
exec /usr/local/bin/microsocks -p 1080 -u "$PROXY_USER" -P "$PROXY_PASSWORD"