#!/bin/sh

# --- Настройка Health Check сервера (для Render) ---
mkdir -p /www/healthz
echo "OK" > /www/healthz/index.html
echo "Starting darkhttpd server for health checks on port 8080..."
darkhttpd /www --port 8080 &
DARKHTTPD_PID=$!

# --- Проверка наличия ключа Tailscale ---
if [ -z "$TAILSCALE_AUTHKEY" ]; then
  echo "Ошибка: Переменная окружения TAILSCALE_AUTHKEY не установлена!"
  exit 1
fi

# --- Запуск Tailscale в Userspace режиме ---
echo "Starting Tailscale daemon (tailscaled) in userspace mode..."
# Добавляем --tun=userspace-networking
tailscaled --state=mem: --tun=userspace-networking &
TAILSCALED_PID=$!

# Даем демону больше времени запуститься, userspace может быть медленнее
sleep 10

echo "Connecting to Tailscale network (tailscale up) using userspace mode..."
# Добавляем --tun=userspace-networking
tailscale up --authkey="${TAILSCALE_AUTHKEY}" --hostname=render-proxy --accept-routes=false --tun=userspace-networking
TS_UP_EXIT_CODE=$?

# Проверяем код возврата 'tailscale up'
if [ $TS_UP_EXIT_CODE -ne 0 ]; then
  echo "Ошибка: tailscale up завершился с кодом $TS_UP_EXIT_CODE. Проверьте Auth Key и логи."
  # В userspace режиме ошибки могут быть не критичными для основной функции,
  # поэтому НЕ выходим сразу, дадим шанс microsocks запуститься.
  # exit 1
fi

echo "Tailscale 'up' command finished. Checking status..."
# Даем время статусу обновиться
sleep 5
# Выводим статус и IP для диагностики
tailscale status || echo "Предупреждение: Не удалось получить статус Tailscale."
tailscale ip -4 || echo "Предупреждение: Не удалось получить Tailscale IPv4."

# Даем сети время стабилизироваться
sleep 3

# --- Запуск microsocks ---
# Слушаем на всех интерфейсах, чтобы поймать и Tailscale IP
echo "Starting microsocks on 0.0.0.0:1080 (with auth)..."
exec /usr/local/bin/microsocks -p 1080

# Если exec не сработает или microsocks упадет, контейнер завершится.
echo "Microsocks exited."
# Опционально: можно остановить фоновые процессы при выходе
# kill $TAILSCALED_PID
# kill $DARKHTTPD_PID