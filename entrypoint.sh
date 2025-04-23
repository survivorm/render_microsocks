#!/bin/sh

# --- Настройка Health Check сервера (для Render) ---
mkdir -p /www/healthz
echo "OK" > /www/healthz/index.html
echo "Starting darkhttpd server for health checks on port 8080..."
darkhttpd /www --port 8080 &
DARKHTTPD_PID=$!

# --- Проверка наличия токена туннеля ---
if [ -z "$TUNNEL_TOKEN" ]; then
  echo "Ошибка: Переменная окружения TUNNEL_TOKEN не установлена!"
  exit 1
fi

# --- Запуск microsocks в фоне ---
# Важно: Заставляем слушать ТОЛЬКО на localhost (127.0.0.1),
# так как подключаться к нему будет только cloudflared из этого же контейнера.
#echo "Starting microsocks on 127.0.0.1:1080 (with auth)..."
#/usr/local/bin/microsocks -i 127.0.0.1 -p 1080 -u "$PROXY_USER" -P "$PROXY_PASSWORD" &
echo "Starting microsocks on 127.0.0.1:1080 (no auth)..."
/usr/local/bin/microsocks -i 127.0.0.1 -p 1080 &
MICROSOCKS_PID=$!

# Даем microsocks время запуститься
sleep 3

# --- Запуск Cloudflare Tunnel Connector ---
# Запускаем cloudflared на переднем плане через exec, чтобы он был основным процессом.
# Он подключится к Cloudflare используя токен и будет ждать входящих туннельных соединений.
# Флаг --url указывает cloudflared, куда перенаправлять TCP-трафик, приходящий через туннель.
echo "Starting Cloudflare Tunnel connector..."
exec cloudflared tunnel --no-autoupdate --url tcp://127.0.0.1:1080 run --token "$TUNNEL_TOKEN"

# Если exec не сработает или cloudflared упадет, контейнер завершится.
# Строки ниже не должны выполниться при нормальной работе.
echo "Cloudflared tunnel exited."
# Можно добавить ожидание фоновых процессов для чистого завершения, но exec обычно достаточно.
# wait $DARKHTTPD_PID
# wait $MICROSOCKS_PID