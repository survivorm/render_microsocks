#!/bin/bash

exec > >(tee -a /var/log/ts-auth.log) 2>&1

echo "=== Tailscale Auth Script Started ==="

MAX_RETRIES=30
COUNT=0
while [ ! -S /var/run/tailscale/tailscaled.sock ]; do
    if [ $COUNT -ge $MAX_RETRIES ]; then
        echo "ERROR: tailscaled.sock not found after $MAX_RETRIES seconds."
        exit 1
    fi
    echo "Waiting for tailscaled socket... ($COUNT)"
    sleep 1
    ((COUNT++))
done

echo "Socket found. Checking Auth Key..."
if [ -z "$TAILSCALE_AUTHKEY" ]; then
    echo "ERROR: TAILSCALE_AUTHKEY is empty!"
    exit 1
fi

auth() {
    tailscale up \
        --auth-key="${TAILSCALE_AUTHKEY}?ephemeral=false&preauthorized=true" \
        --hostname="render-proxy" \
        --advertise-tags=tag:render-proxy \
        --accept-dns=false \
        --accept-routes=false \
        --netfilter-mode=off
}

echo "Running tailscale up..."
if auth; then
    echo "=== Tailscale Auth SUCCESS ==="
else
    echo "=== Tailscale Auth FAILED ==="
    exit 1
fi

while true; do
    sleep 60
    if ! tailscale status 2>/dev/null | head -1 | grep -q render-proxy; then
        echo "Tailscale disconnected. Re-authenticating..."
        auth
    fi
done
