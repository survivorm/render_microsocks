# --- Этап 1: Сборщик (остается без изменений) ---
FROM alpine:latest AS builder
RUN apk update && apk add --no-cache git build-base
RUN git clone https://github.com/rofl0r/microsocks.git /opt/microsocks
RUN cd /opt/microsocks && \
    make CFLAGS="-static -Os"

# --- Этап 2: Финальный образ ---
FROM alpine:latest

# Устанавливаем curl (для скачивания cloudflared), darkhttpd, busybox и другие зависимости.
# Удаляем cloudflared из apk add
RUN apk update && \
    apk add --no-cache curl darkhttpd busybox libc6-compat && \
    echo "Установка базовых пакетов завершена." && \
    # Скачиваем последнюю версию cloudflared для linux-amd64
    echo "Скачивание cloudflared..." && \
    curl -L --output /usr/local/bin/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 && \
    # Делаем скачанный файл исполняемым
    chmod +x /usr/local/bin/cloudflared && \
    # Проверяем версию (опционально, для лога)
    echo "cloudflared версия:" && \
    cloudflared --version && \
    # Очищаем кэш apk
    rm -rf /var/cache/apk/*

# Копируем скомпилированный microsocks из этапа сборщика
COPY --from=builder /opt/microsocks/microsocks /usr/local/bin/microsocks
RUN chmod +x /usr/local/bin/microsocks

# Копируем наш скрипт запуска
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Переменные окружения
ENV PROXY_USER="default_user"
ENV PROPY_PASSWORD="default_password"
ENV TUNNEL_TOKEN="ttt"

# Открываем порты
EXPOSE 1080
EXPOSE 8080

# Используем ENTRYPOINT для запуска нашего скрипта
ENTRYPOINT ["/entrypoint.sh"]