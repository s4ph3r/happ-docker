# Happ Desktop + Selkies — Docker образ

Docker-образ, объединяющий **Happ Desktop** (клиент VPN/прокси) и **Selkies** (удалённый рабочий стол через браузер).

Образ собран для работы на TrueNAS SCALE с сохранением конфигурации и данных.

---

## Что внутри

- **Happ Desktop** (`/opt/happ`) — GUI-клиент прокси (xray-core)
- **Xvfb + Openbox** — виртуальный дисплей для GUI
- **Selkies** (`pip install selkies`) — стриминг рабочего стола через WebSockets
- **Nginx** — HTTPS reverse-proxy для Selkies (самоподписанный сертификат)
- **PipeWire + WirePlumber** — аудио (если понадобится)

---

## Порты

| Порт  | Сервис | Протокол |
|-------|--------|----------|
| 443   | Nginx (HTTPS) → Selkies | HTTPS / WebSockets |
| 10808 | Happ (xray) | HTTP-прокси |
| 10809 | Happ (xray) | SOCKS5-прокси |
| 80    | Nginx (HTTP) | редирект → 443 |

**Внешний доступ:**
- Веб-морда: `https://<IP-сервера>:443` (или порт проброски TrueNAS, например 33080)
- SOCKS5 прокси: `<IP-сервера>:10809`
- HTTP прокси: `<IP-сервера>:10808`

---

## Тома (где монтируются настройки и данные)

| Точка монтирования в контейнере | Что хранится |
|--------------------------------|--------------|
| `/root/.config/Happ` | База подписок (`subs.db`) |
| `/root/.config/Happ.conf` | Основной конфиг приложения (Preferences, ключи) |
| `/root/.local/share/Happ` | Данные: `stories.db`, `premium-fallback.bin/ts`, `dumps/`, `logs/`, `routing/`, `update/` |
| `/var/lib/happd` | Данные daemon: `state.db`, `push_creds.json` |

> ⚠️ **Важно:** каталог `/root/.config/Happ` (с заглавной H) и файл `/root/.config/Happ.conf` — это **два разных пути**, которые должны быть доступны через volume.

При пересоздании контейнера **не забывайте сохранять и монтировать все четыре пути**.

---

## Как обновить Happ до новой версии

### 1. Скачайте новый `.deb` пакет

Скачайте обновлённый `Happ.linux.x64.deb` с официального источника (GitHub releases Happ-proxy/happ-desktop).

### 2. Замените файл в проекте

```bash
cd /home/user/happ-desktop/docker
cp /path/to/new/Happ.linux.x64.deb ./Happ.linux.x64.deb
```

### 3. Пересоберите образ

```bash
docker build --no-cache -t happ-desktop:v6 .
```

> ⚠️ **`--no-cache` обязателен!** Без него Docker может использовать закешированную копию старого `.deb` и не возьмёт новый файл.

### 4. Проверьте версию пакета (опционально)

```bash
# Перед заменой файла проверьте версию старого пакета:
dpkg-deb -I ./Happ.linux.x64.deb | grep Version

# Или после замены:
dpkg-deb -I ./Happ.linux.x64.deb | grep Version
```

### 5. Сохраните и загрузите образ на сервер

```bash
docker save --output /tmp/happ-desktop-v6.tar localhost/happ-desktop:v6
scp /tmp/happ-desktop-v6.tar root@<IP-сервера>:/tmp/
ssh root@<IP-сервера> "docker load -i /tmp/happ-desktop-v6.tar"
```

### 6. Пересоздайте контейнер

В TrueNAS SCALE → Apps → редактировать контейнер → обновить образ до `happ-desktop:v6` → перезапустить.

---

## Как пересобрать образ с нуля

### Предварительные условия

- Docker / Podman
- Файл `Happ.linux.x64.deb` в директории проекта (или замените путь в `Dockerfile`)

### Команды

```bash
cd /home/user/happ-desktop/docker

# Полная пересборка без кеша (обязательно при замене .deb)
docker build --no-cache -t happ-desktop:v6 .

# Сохранить образ
docker save --output /tmp/happ-desktop-v6.tar localhost/happ-desktop:v6
```

### Файлы проекта

```
.
├── Dockerfile          # Инструкции сборки образа
├── start.sh            # Скрипт запуска сервисов внутри контейнера
├── lxqt.conf           # Конфиг LXQt (по умолчанию)
├── docker-compose.yml  # Docker Compose (локальный запуск)
├── run-happ.sh         # Скрипт запуска с volume mount
├── Happ.linux.x64.deb  # Пакет Happ (обновляем вручную)
└── README.md           # Этот файл
```

---

## Как запустить контейнер

### Через Docker Compose

```bash
cd /home/user/happ-desktop/docker
docker compose up -d
```

### Через run-happ.sh

```bash
cd /home/user/happ-desktop/docker
./run-happ.sh /путь/к/настройкам /путь/к/данным
```

### Через TrueNAS SCALE (Custom App)

Конфиг:

```yaml
services:
  happ-desktop:
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    environment:
      NVIDIA_VISIBLE_DEVICES: void
      TZ: Europe/Moscow
    image: localhost/happ-desktop:v6
    platform: linux/amd64
    ports:
      - mode: ingress
        protocol: tcp
        published: 10808
        target: 10808
      - mode: ingress
        protocol: tcp
        published: 10809
        target: 10809
      - mode: ingress
        protocol: tcp
        published: 33080
        target: 443
    privileged: False
    restart: always
    user: '0:0'
    volumes:
      - bind:
          source: /mnt/.ix-apps/app_mounts/happ-desktop/config
          target: /root/.config
          type: bind
      - bind:
          source: /mnt/.ix-apps/app_mounts/happ-desktop/data
          target: /root/.local/share/Happ
          type: bind
      - bind:
          source: /mnt/.ix-apps/app_mounts/happ-desktop/db
          target: /var/lib/happd
          type: bind
```

---

## Как проверить что прокси работает

```bash
# HTTP-прокси (10808)
curl -x http://<IP-сервера>:10808 http://ipinfo.io

# SOCKS5-прокси (10809)
curl --socks5 <IP-сервера>:10809 http://ipinfo.io
```

Успешный ответ должен содержать JSON с полями `ip`, `city`, `country`.

---

## Ошибки и их решения

### `no such file or directory` (TUN)

Контейнер не имеет устройства `/dev/net/tun`. Решение: добавить в конфиг:

```yaml
cap_add:
  - NET_ADMIN
devices:
  - /dev/net/tun:/dev/net/tun
```

### `Permission denied` при создании `.config`

Happ запускается от root, но директории создавались для UID 1000. Решение: убрать `USER 1000` из Dockerfile, использовать `root:root` для всех путей.

### 502 Bad Gateway (Nginx)

Nginx не может подключиться к Selkies. Проверьте:

```bash
docker exec <контейнер> ps aux | grep selkies
docker logs <контейнер> 2>&1 | grep -i selkies
```

Selkies должен запускаться как `env DISPLAY=:99 selkies --port=8080 ...` (без `--session`, который поднимает собственный Xvfb).

### Happ не отображается в Selkies

Selkies показывал пустой экран — потому что запускался через `selkies session`, который поднимал **собственный Xvfb**. Решение: запускать `selkies` напрямую с `DISPLAY=:99` (см. `start.sh`).

---

## Обновление версии образа

При каждой сборке:

1. Укажите новую теговую версию в `docker build` (например `v7`)
2. Сохраните образ с новым тегом
3. Загрузите на сервер
4. Пересоздайте контейнер в TrueNAS

```bash
docker build --no-cache -t happ-desktop:v7 .
docker save --output /tmp/happ-desktop-v7.tar localhost/happ-desktop:v7
scp /tmp/happ-desktop-v7.tar root@<IP-сервера>:/tmp/
ssh root@<IP-сервера> "docker load -i /tmp/happ-desktop-v7.tar"
```

---

## Лицензия

Образ содержит Happ Desktop (см. лицензию Happ-proxy/happ-desktop) и Selkies (см. лицензию selkies-project/selkies).
