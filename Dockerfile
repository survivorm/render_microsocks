# --- Этап 1: Сборщик (остается без изменений) ---
FROM alpine:latest AS builder
RUN apk update && apk add --no-cache git build-base
RUN git clone https://github.com/rofl0r/microsocks.git /opt/microsocks
RUN cd /opt/microsocks && \
    make CFLAGS="-static -Os"

# --- Этап 2: Финальный образ ---
FROM alpine:latest

# устанавливаем tailscale, darkhttpd, busybox, bind-tools (для nslookup) и curl (для теста)
RUN apk update && \
    apk add --no-cache \
        supervisor \
        curl \
        darkhttpd \
        tailscale \
        bash && \
        busybox \
        bind-tools \
        libc6-compat
    echo "Установка пакетов завершена." && \
    # Очищаем кэш apk после успешной установки
    rm -rf /var/cache/apk/*

# Копируем скомпилированный microsocks из этапа сборщика
COPY --from=builder /opt/microsocks/microsocks /usr/local/bin/microsocks
RUN chmod +x /usr/local/bin/microsocks

# Копируем наш скрипт запуска
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Переменные окружения
ENV PROXY_USER="default_user"
ENV PROXY_PASSWORD="default_password"
ENV TAILSCALE_AUTHKEY="fff"

# Открываем порты (1080 для microsocks, 8080 для health check)
EXPOSE 1080
EXPOSE 8080

# Используем ENTRYPOINT для запуска нашего скрипта
ENTRYPOINT ["/entrypoint.sh"]