#!/bin/bash
# Запуск контейнера Happ Desktop + Selkies
#
# Использование:
#   ./run-happ.sh [путь_к_настройкам] [путь_к_данным]
#
# По умолчанию:
#   настройки: ~/happ-config
#   данные:    ~/happ-data

HAPP_CONFIG_DIR="${1:-$HOME/happ-config}"
HAPP_DATA_DIR="${2:-$HOME/happ-data}"

# Создаем директории если нет
mkdir -p "$HAPP_CONFIG_DIR" "$HAPP_DATA_DIR"

echo "=== Запуск Happ Desktop + Selkies ==="
echo "Настройки: $HAPP_CONFIG_DIR"
echo "Данные:    $HAPP_DATA_DIR"
echo "HTTPS веб-морда: https://localhost:443"
echo "SOCKS5 прокси: localhost:10809"
echo "HTTP прокси:  localhost:10808"
echo ""

docker run -d \
    --name happ-desktop \
    --restart unless-stopped \
    -p 443:443 \
    -p 10809:10809 \
    -p 10808:10808 \
    -v "${HAPP_CONFIG_DIR}:/root/.config/happ" \
    -v "${HAPP_DATA_DIR}:/root/.local/share/happ" \
    -e DISPLAY=:99 \
    -e SELKIES_PORT=8080 \
    -e SELKIES_MODE=websockets \
    happ-desktop:v4

echo ""
echo "Контейнер запущен."
echo "Подключиться к рабочему столу: https://localhost:443"
echo "SOCKS5 прокси: localhost:10809"
echo "HTTP прокси:  localhost:10808"
