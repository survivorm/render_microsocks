#!/bin/sh

# --- Настройка Health Check ---
# ... (darkhttpd) ...
echo "Starting darkhttpd server for health checks on port 8080..."
darkhttpd /www --port 8080 &
DARKHTTPD_PID=$!

# --- Проверка ключа Tailscale ---
# ... (проверка TAILSCALE_AUTHKEY) ...

# --- Запуск Tailscale ---
echo "Starting Tailscale daemon (tailscaled) in userspace mode..."
tailscaled --state=mem: --tun=userspace-networking &
TAILSCALED_PID=$!
sleep 10

echo "Connecting to Tailscale network (tailscale up)..."
tailscale up --authkey="${TAILSCALE_AUTHKEY}" --hostname=render-proxy --accept-routes=false
TS_UP_EXIT_CODE=$?
if [ $TS_UP_EXIT_CODE -ne 0 ]; then
  echo "Ошибка: tailscale up завершился с кодом $TS_UP_EXIT_CODE."
  exit 1
fi
sleep 5
echo "--- Tailscale Status ---"
tailscale status || echo "WARN: Не удалось получить статус Tailscale."
tailscale ip -4 || echo "WARN: Не удалось получить Tailscale IPv4."
echo "------------------------"
sleep 3

# --- Тесты Доступа к Google API ---
GOOGLE_API_HOST="generativelanguage.googleapis.com"
echo "--- Testing DNS resolution for ${GOOGLE_API_HOST} ---"
nslookup ${GOOGLE_API_HOST} || echo "WARN: nslookup ${GOOGLE_API_HOST} failed!"
echo "---------------------------------------------------"
sleep 2
echo "--- Testing connectivity (curl HEAD) to https://${GOOGLE_API_HOST} ---"
curl -I -m 10 "https://${GOOGLE_API_HOST}" # HEAD request, 10 sec timeout
CURL_EXIT_CODE=$?
if [ $CURL_EXIT_CODE -ne 0 ]; then
  echo "WARN: Failed to connect to https://${GOOGLE_API_HOST} (Exit code: $CURL_EXIT_CODE)"
else
  echo "OK: Connection test to https://${GOOGLE_API_HOST} successful."
fi
echo "---------------------------------------------------------------------"
sleep 2
# --- Конец Тестов ---

# --- Запуск microsocks ---
echo "Starting microsocks on 0.0.0.0:1080 (with auth)..."
# Убедись, что параметры -u и -P соответствуют твоему текущему состоянию
exec /usr/local/bin/microsocks -p 1080

echo "Microsocks exited."