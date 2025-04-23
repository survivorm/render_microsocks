# --- Этап 1: Сборщик ---
# Используем Alpine как базу для сборки
FROM alpine:latest AS builder

# Устанавливаем инструменты, необходимые для сборки: git (чтобы скачать код) и build-base (gcc, make и т.д.)
RUN apk update && apk add --no-cache git build-base

# Клонируем репозиторий microsocks
# Используем официальный репозиторий (или форк, если нужно)
RUN git clone https://github.com/rofl0r/microsocks.git /opt/microsocks

# Переходим в папку с исходниками и компилируем
# Флаг -static может помочь сделать бинарник более переносимым, хотя и не всегда нужен/возможен в Alpine
# Флаг -Os для оптимизации размера
RUN cd /opt/microsocks && \
    make CFLAGS="-static -Os"

# --- Этап 2: Финальный образ ---
# Начинаем с чистого образа Alpine
FROM alpine:latest

# Устанавливаем только РЕАЛЬНО необходимые зависимости для работы microsocks (если они есть)
# В данном случае, скорее всего, кроме стандартной библиотеки libc (которая уже есть), ничего не нужно.
# RUN apk add --no-cache some-runtime-dependency

# Копируем ТОЛЬКО скомпилированный бинарник из этапа сборщика
COPY --from=builder /opt/microsocks/microsocks /usr/local/bin/microsocks

# Устанавливаем права на исполнение (на всякий случай)
RUN chmod +x /usr/local/bin/microsocks

# Задаем переменные окружения для имени пользователя и пароля.
# Render позволит установить их значения при деплое.
ENV PROXY_USER="default_user"
ENV PROXY_PASSWORD="default_password"

# Стандартный порт для SOCKS - 1080
EXPOSE 1080

# Команда для запуска УЖЕ УСТАНОВЛЕННОГО microsocks
# Путь теперь /usr/local/bin/microsocks
CMD ["/usr/local/bin/microsocks", "-p", "1080", "-u", "$PROXY_USER", "-P", "$PROXY_PASSWORD"]