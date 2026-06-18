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

# IP forwarding для exit-node (может не сработать без привилегий)
echo 'net.ipv4.ip_forward = 1' > /etc/sysctl.d/99-tailscale.conf 2>/dev/null || true
echo 'net.ipv6.conf.all.forwarding = 1' >> /etc/sysctl.d/99-tailscale.conf 2>/dev/null || true
sysctl -p /etc/sysctl.d/99-tailscale.conf 2>/dev/null || echo "Warning: sysctl failed (exit-node may still work in userspace mode)"

echo "Starting supervisord..."
exec /usr/bin/supervisord -c /etc/supervisord.conf -n