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
        bash \
        busybox \
        bind-tools \
        libc6-compat && \
    echo "Установка пакетов завершена." && \
    # Очищаем кэш apk после успешной установки
    rm -rf /var/cache/apk/*

# Копируем скомпилированный microsocks из этапа сборщика
COPY --from=builder /opt/microsocks/microsocks /usr/local/bin/microsocks
RUN chmod +x /usr/local/bin/microsocks

# Переменные окружения
ENV PROXY_USER="default_user"
ENV PROXY_PASSWORD="default_password"
ENV TAILSCALE_AUTHKEY="fff"

# Открываем порты (1080 для microsocks, 8080 для health check)
EXPOSE 1080
EXPOSE 8080

# Копируем конфигурационный файл supervisord В СТАНДАРТНОЕ МЕСТО
COPY supervisord.conf /etc/supervisord.conf

# Копируем скрипты
COPY entrypoint.sh /entrypoint.sh
COPY ts-auth.sh /usr/local/bin/ts-auth.sh
RUN chmod +x /entrypoint.sh /usr/local/bin/ts-auth.sh

# Создаем директорию для статики и файл для Health Check
RUN mkdir -p /www/healthz && \
    echo "ok" > /www/healthz/index.html

# Указываем, что контейнер будет запускаться через наш entrypoint
ENTRYPOINT ["/entrypoint.sh"]
