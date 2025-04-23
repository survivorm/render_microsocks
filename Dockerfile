# --- Этап 1: Сборщик (остается без изменений) ---
FROM alpine:latest AS builder
RUN apk update && apk add --no-cache git build-base
RUN git clone https://github.com/rofl0r/microsocks.git /opt/microsocks
RUN cd /opt/microsocks && \
    make CFLAGS="-static -Os"

# --- Этап 2: Финальный образ ---
FROM alpine:latest

# Устанавливаем darkhttpd для health check, busybox и другие зависимости.
RUN apk update && \
    apk add --no-cache darkhttpd busybox libc6-compat && \
    echo "Установка darkhttpd завершена." && \
    rm -rf /var/cache/apk/*

# Копируем скомпилированный microsocks из этапа сборщика
COPY --from=builder /opt/microsocks/microsocks /usr/local/bin/microsocks
RUN chmod +x /usr/local/bin/microsocks

# Копируем наш скрипт запуска
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Переменные окружения для microsocks
ENV PROXY_USER="default_user"
ENV PROXY_PASSWORD="default_password"

# Открываем ОБА порта: 1080 для SOCKS, 8080 для Health Check HTTP
EXPOSE 1080
EXPOSE 8080

# Используем ENTRYPOINT для запуска нашего скрипта
ENTRYPOINT ["/entrypoint.sh"]