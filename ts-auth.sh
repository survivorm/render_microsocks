#!/bin/bash
echo "Waiting for tailscaled socket..."
while [ ! -S /var/run/tailscale/tailscaled.sock ]; do
    sleep 1
done

echo "Authenticating Tailscale..."
# Добавляем --ephemeral, чтобы узел удалялся из панели после выключения контейнера
# Добавляем --advertise-exit-node, если хочешь использовать его как Exit Node
tailscale up --authkey="${TAILSCALE_AUTHKEY}" \
             --hostname="render-proxy" \
             --accept-dns=false \
             --accept-routes=false \
             --netfilter-mode=off \
             --ephemeral

echo "Tailscale is up and authenticated."