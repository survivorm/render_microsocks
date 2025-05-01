#!/bin/sh

# Включаем вывод команд и остановку при ошибке для секции настройки
set -e
# set -x # Раскомментируй для детальной отладки

echo "Entrypoint: Starting setup..."

# --- Проверка ключа Tailscale ---
if [ -z "${TAILSCALE_AUTHKEY}" ]; then
  echo "Ошибка: Переменная окружения TAILSCALE_AUTHKEY не установлена."
  exit 1
fi
echo "TAILSCALE_AUTHKEY is set."

# --- Запуск tailscaled (временно, только для setup) ---
# Supervisord будет управлять основным процессом tailscaled позже.
# Мы запускаем его здесь только для команды 'tailscale up'.
echo "Starting tailscaled in background for setup..."
tailscaled --state=mem: --tun=userspace-networking &
TAILSCALED_SETUP_PID=$!

# Даем время демону запуститься (можно заменить на проверку сокета)
echo "Waiting for tailscaled daemon (setup)..."
sleep 10 # Или более надежная проверка: while [ ! -S /var/run/tailscale/tailscaled.sock ]; do sleep 1; done

# --- Подключение к Tailscale ---
echo "Connecting to Tailscale network (tailscale up)..."
# Используем --accept-dns=false, если не хотим использовать DNS Tailscale
# Используем --netfilter-mode=off (или userspace?), если возникают проблемы с userspace-networking туннелем
tailscale up --authkey="${TAILSCALE_AUTHKEY}" --hostname=render-proxy --accept-routes=false --accept-dns=false --netfilter-mode=off
TS_UP_EXIT_CODE=$?
if [ $TS_UP_EXIT_CODE -ne 0 ]; then
  echo "Ошибка: tailscale up завершился с кодом $TS_UP_EXIT_CODE."
  # Попробуем остановить временный tailscaled перед выходом
  kill $TAILSCALED_SETUP_PID 2>/dev/null || true
  exit 1
fi
echo "Tailscale connection command executed."
sleep 5 # Даем время на установку соединения

# --- Проверка статуса Tailscale ---
echo "--- Tailscale Status ---"
tailscale status || echo "WARN: Не удалось получить статус Tailscale."
tailscale ip -4 || echo "WARN: Не удалось получить Tailscale IPv4."
echo "------------------------"
sleep 3

# --- Тесты Доступа к Google API (Опционально, но полезно) ---
GOOGLE_API_HOST="generativelanguage.googleapis.com"
echo "--- Testing connectivity to https://${GOOGLE_API_HOST} via Tailscale Interface (if applicable) ---"
# Можно попробовать указать интерфейс tailscale0, если он есть и активен
# TS_INTERFACE=$(tailscale ip -4 | head -n1) # Получаем IP, интерфейс может быть tailscale0
# curl -I -m 10 --interface tailscale0 "https://${GOOGLE_API_HOST}" || curl -I -m 10 "https://${GOOGLE_API_HOST}"
# Упрощенный тест без указания интерфейса:
curl -I -v -m 15 "https://${GOOGLE_API_HOST}" # -v для verbose вывода, таймаут 15 сек
CURL_EXIT_CODE=$?
if [ $CURL_EXIT_CODE -ne 0 ]; then
  echo "WARN: Failed to connect to https://${GOOGLE_API_HOST} (Exit code: $CURL_EXIT_CODE)"
else
  echo "OK: Connection test to https://${GOOGLE_API_HOST} successful."
fi
echo "---------------------------------------------------------------------"
sleep 2
# --- Конец Тестов ---

# --- Остановка временного tailscaled ---
# Supervisord запустит и будет управлять своим экземпляром tailscaled.
echo "Stopping temporary tailscaled (PID $TAILSCALED_SETUP_PID) used for setup..."
kill $TAILSCALED_SETUP_PID
# Ждем немного, чтобы он корректно завершился (опционально)
wait $TAILSCALED_SETUP_PID 2>/dev/null || true
echo "Temporary tailscaled stopped."

# Отключаем set -e перед запуском supervisord, чтобы он мог управлять падениями
set +e

# --- Запуск Supervisord ---
# Он прочитает supervisord.conf и запустит все настроенные программы
# Используем exec, чтобы supervisord стал основным процессом контейнера (PID 1)
echo "Setup complete. Handing control over to supervisord..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf -n

# Этот код ниже никогда не должен выполниться, если exec сработал
echo "ERROR: Supervisord failed to start!"
exit 1