#!/bin/bash

# Выводим всё в консоль для отладки Render
exec > >(tee -a /var/log/ts-auth.log) 2>&1

echo "=== Tailscale Auth Script Started ==="

# Ждем появления сокета
MAX_RETRIES=30
COUNT=0
while [ ! -S /var/run/tailscale/tailscaled.sock ]; do
    if [ $COUNT -ge $MAX_RETRIES ]; then
        echo "ERROR: tailscaled.sock not found after $MAX_RETRIES seconds. Exiting."
        exit 1
    fi
    echo "Waiting for tailscaled socket... ($COUNT)"
    sleep 1
    ((COUNT++))
done

echo "Socket found. Checking Auth Key..."
if [ -z "$TAILSCALE_AUTHKEY" ]; then
    echo "ERROR: TAILSCALE_AUTHKEY is empty in ts-auth.sh!"
    exit 1
fi

echo "Running tailscale up..."
# Добавляем --reset для очистки старых попыток
tailscale up \
    --reset \
    --authkey="${TAILSCALE_AUTHKEY}" \
    --hostname="render-proxy" \
    --accept-dns=false \
    --accept-routes=false \
    --netfilter-mode=off \
    --ephemeral

if [ $? -eq 0 ]; then
    echo "=== Tailscale Auth SUCCESS ==="
else
    echo "=== Tailscale Auth FAILED (Exit Code $?) ==="
    exit 1
fi