#!/bin/bash
set -e

echo "=== Happ Desktop + Selkies Container ==="
echo "Starting services..."

# ============================================
# 1. Runtime directories (создаём от root, потом меняем владельца)
# ============================================
export XDG_RUNTIME_DIR=/run/user/0
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
chown root:root "$XDG_RUNTIME_DIR"

# PipeWire runtime
mkdir -p /tmp/pipewire-0
chmod 755 /tmp/pipewire-0

# ============================================
# 2. D-Bus session bus
# ============================================
echo "[*] Starting D-Bus..."
dbus-daemon --session --address="unix:path=$XDG_RUNTIME_DIR/bus" --fork --print-pid > /dev/null 2>&1 || true
export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"

# ============================================
# 3. Xvfb virtual display
# ============================================
echo "[*] Starting Xvfb on :99..."

if [ -f /tmp/.X99-lock ]; then
    kill $(cat /tmp/.X99-lock) 2>/dev/null || true
    rm -f /tmp/.X99-lock
    sleep 1
fi

Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset &
export DISPLAY=:99

for i in $(seq 1 30); do
    if xdpyinfo -display :99 > /dev/null 2>&1; then
        echo "[+] Xvfb is ready"
        break
    fi
    sleep 0.5
done

# ============================================
# 4. PipeWire + WirePlumber (audio)
# ============================================
echo "[*] Starting PipeWire..."
pipewire &
sleep 1

echo "[*] Starting WirePlumber..."
wireplumber &
sleep 1

# ============================================
# 5. Window Manager (Openbox)
# ============================================
echo "[*] Starting Openbox..."
openbox --sm-disable &
sleep 1

# ============================================
# 6. Set environment for Happ
# ============================================
export QT_QPA_PLATFORM=xcb
export QT_PLUGIN_PATH=/opt/happ/lib/plugins
export QML2_IMPORT_PATH=/opt/happ/lib/qml
export LD_LIBRARY_PATH=/opt/happ/lib:$LD_LIBRARY_PATH
export PATH="/opt/happ/bin:/opt/happ/bin/core:/opt/happ/bin/tun:/opt/happ/bin/tun2:$PATH"

# ============================================
# 7. Start Happ Desktop
# ============================================
echo "[*] Starting Happ Desktop..."
cd /opt/happ/bin

/opt/happ/bin/Happ --background >> /var/log/happ.log 2>&1 &
HAPP_PID=$!

for i in $(seq 1 10); do
    if kill -0 $HAPP_PID 2>/dev/null; then
        echo "[+] Happ Desktop started (PID: $HAPP_PID)"
        break
    fi
    sleep 1
done

if ! kill -0 $HAPP_PID 2>/dev/null; then
    echo "[-] Happ Desktop failed to start!"
    tail -20 /var/log/happ.log || true
fi

echo "    Config dir: /root/.config/happ"
echo "    Data dir:   /root/.local/share/happ"
echo ""

# ============================================
# 8. Start Selkies (без --session, без auth)
# ============================================
echo "[*] Starting Selkies..."

SELKIES_PORT=${SELKIES_PORT:-8080}
SELKIES_MODE=${SELKIES_MODE:-websockets}

echo "    Selkies port: $SELKIES_PORT"
echo "    Selkies mode: $SELKIES_MODE"

# Запускаем selkies напрямую с существующим дисплеем :99
# (selkies считывает DISPLAY из окружения, не поднимает свой Xvfb)
nohup env DISPLAY=:99 selkies \
    --port=$SELKIES_PORT \
    --encoder=h264enc \
    --use-cpu=true \
    --enable-basic-auth=false \
    > /var/log/selkies.log 2>&1 &

echo "[+] Selkies started on port $SELKIES_PORT"
echo ""

# ============================================
# 9. Start Nginx as HTTPS reverse proxy
# ============================================
echo "[*] Starting Nginx (HTTPS proxy)..."

cat > /etc/nginx/sites-available/default << 'NGINX'
server {
    listen 443 ssl;
    server_name localhost;

    ssl_certificate /etc/nginx/ssl/happ.crt;
    ssl_certificate_key /etc/nginx/ssl/happ.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }
}

server {
    listen 80;
    server_name localhost;
    return 301 https://$host$request_uri;
}
NGINX

nginx -t && nginx &

echo "[+] Nginx started on port 443 (HTTPS)"
echo ""

# ============================================
# 10. Summary
# ============================================
echo "=========================================="
echo "  Services running:"
echo "  - Xvfb (display :99)"
echo "  - Openbox (window manager)"
echo "  - Happ Desktop (proxy client)"
echo "  - Selkies (remote desktop) -> port $SELKIES_PORT"
echo "  - Nginx (HTTPS proxy) -> port 443"
echo ""
echo "  Proxy ports (exposed):"
echo "  - SOCKS5:   port 1080"
echo "  - HTTP:     port 1081"
echo "=========================================="

# ============================================
# 11. Keep container alive
# ============================================
wait $HAPP_PID
