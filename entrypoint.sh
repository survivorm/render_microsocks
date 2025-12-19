#!/bin/sh
set -e

# Проверка ключа
if [ -z "${TAILSCALE_AUTHKEY}" ]; then
  echo "Error: TAILSCALE_AUTHKEY is not set"
  exit 1
fi

# Подготовка папок (Tailscale может капризничать без них)
mkdir -p /var/run/tailscale /var/lib/tailscale /dev/net
if [ ! -c /dev/net/tun ]; then
    # Это может не сработать на Render без привилегий,
    # но userspace-networking это прощает
    mknod /dev/net/tun c 10 200 || true
fi

echo "Starting supervisord..."
exec /usr/bin/supervisord -c /etc/supervisord.conf -n