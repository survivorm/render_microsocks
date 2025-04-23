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

# --- Запуск Tailscale ---
echo "Starting Tailscale daemon (tailscaled)..."
# Запускаем демона в фоне. Флаг --state=mem: указывает хранить состояние в памяти (важно для Render)
tailscaled --state=mem: &
TAILSCALED_PID=$!

# Даем демону время запуститься
sleep 5

echo "Connecting to Tailscale network (tailscale up)..."
# Подключаемся к сети, используя Auth Key.
# --hostname=render-proxy : Устанавливаем имя хоста в сети Tailscale
# --accept-routes=false : Обычно не нужно принимать маршруты для простого узла/прокси
tailscale up --authkey="${TAILSCALE_AUTHKEY}" --hostname=render-proxy --accept-routes=false
TS_UP_EXIT_CODE=$?

if [ $TS_UP_EXIT_CODE -ne 0 ]; then
  echo "Ошибка: tailscale up завершился с кодом $TS_UP_EXIT_CODE. Проверьте Auth Key и логи."
  exit 1
fi

echo "Tailscale connected successfully."
# Можно добавить вывод IP: tailscale ip -4

# Даем сети время стабилизироваться
sleep 3

# --- Запуск microsocks ---
echo "Starting microsocks on 0.0.0.0:1080 (with auth)..."
# Слушаем на всех интерфейсах (0.0.0.0), включая Tailscale IP.
# Возвращаем аутентификацию, т.к. теперь доступ к порту будет только через защищенную сеть Tailscale.
exec /usr/local/bin/microsocks -p 1080

# Если exec не сработает или microsocks упадет, контейнер завершится.
echo "Microsocks exited."
# Опционально: можно остановить фоновые процессы при выходе
# kill $TAILSCALED_PID
# kill $DARKHTTPD_PID