<div align="center">

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║    ██████╗ ███████╗███╗   ███╗██████╗ ███████╗██████╗                         ║
║    ██╔══██╗██╔════╝████╗ ████║██╔══██╗██╔════╝██╔══██╗                        ║
║    ██████╔╝█████╗  ██╔████╔██║██████╔╝█████╗  ██████╔╝                        ║
║    ██╔══██╗██╔══╝  ██║╚██╔╝██║██╔══██╗██╔══╝  ██╔══██╗                        ║
║    ██║  ██║███████╗██║ ╚═╝ ██║██████╔╝███████╗██║  ██║                        ║
║    ╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝╚═════╝ ╚══════╝╚═╝  ╚═╝                        ║
║                                                                               ║
║           ╔═╗╔╦╗╦═╗╦╔═╗╔╗ ╦╔═╗  ╦  ╔═╗╔═╗╔═╗╔╗╔╔═╗╔═╗                      ║
║           ║╣ ║║║╠╦╝║╠═╣╠╩╗║║   ║  ║ ║║ ║╠═╣║║║╚═╗║╣                        ║
║           ╚═╝╩ ╩╩╚═╩╩ ╩╚═╝╩╚═╝ ╩═╝╚═╝╚═╝╩ ╩╝╚╝╚═╝╚═╝                      ║
║                                                                               ║
║           🎪 btop-style TUI Installer for Remnawave 🎪                       ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

# 🌈 Установка одной командой

### `bash <(curl -Ls https://raw.githubusercontent.com/Nurulaev/install-remnawave/main/install_remnawave.sh)`

**✨ Самый красивый способ установить Remnawave ✨**

[![Version](https://img.shields.io/badge/-version-2.1.0-brightgreen?style=for-the-badge&logo=terminal)](https://github.com/Nurulaev/install-remnawave)
[![License](https://img.shields.io/badge/license-MIT-blue?style=for-the-badge)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Debian%20%7C%20Ubuntu-orange?style=for-the-badge&logo=linux)]()
[![Remnawave](https://img.shields.io/badge/Remnawave-v3-purple?style=for-the-badge)](https://github.com/remnawave)
[![Docker](https://img.shields.io/badge/Docker-✅-brightgreen?style=for-the-badge&logo=docker)](https://www.docker.com)

---

</div>

## 🎭 Что это?

Интерактивный установщик Remnawave панели в стиле **btop** — с рамками `╭╮╰╯`, прогресс-барами `███░░░`, анимированными спиннерами `⠋⠙⠹` и радужным баннером.

> *"В Стране Чудес всё должно быть красочно — даже установка VPN панели"* 🐇

---

## 🪞 Как выглядит

```
    ╔═╗╔╦╗╦═╗╦╔═╗╔╗ ╦╔═╗  ╦  ╔═╗╔═╗╔═╗╔╗╔╔═╗╔═╗
    ║╣ ║║║╠╦╝║╠═╣╠╩╗║║   ║  ║ ║║ ║╠═╣║║║╚═╗║╣
    ╚═╝╩ ╩╩╚═╩╩ ╩╚═╝╩╚═╝ ╩═╝╚═╝╚═╝╩ ╩╝╚╝╚═╝╚═╝

      Remnawave Panel Installer · btop edition · v2.1.0

    ╭──────────────────── SYSTEM CHECK ─────────────────────╮
    │                                                        │
    │  Root access confirmed                         [✔]     │
    │  OS: Debian GNU/Linux 12 (bookworm)            [✔]     │
    │  Docker: 27.5.1                                [✔]     │
    │  Compose: v2.32.4                              [✔]     │
    │                                                        │
    │  ████████████████████████░░░░░░░░  67%  Deploying...   │
    │                                                        │
    ╰────────────────────────────────────────────────────────╯
```

---

## 🎯 Меню — 11 опций

| # | Эмодзи | Действие | Описание |
|---|--------|----------|----------|
| **1** | 🚀 | **Установить** | Панель + Caddy + подписочная страница |
| **2** | 🌍 | **Нода** | Установка ноды на отдельном сервере |
| **3** | 📊 | **Статус** | Контейнеры / health / порты / диск |
| **4** | 🔄 | **Обновить** | Pull образов + пересоздание |
| **5** | 🔁 | **Перезапустить** | Все сервисы |
| **6** | 📋 | **Логи** | Просмотр контейнеров |
| **7** | 💾 | **Бэкап** | pg_dumpall + конфиги → tar.gz |
| **8** | 🔒 | **Сертификаты** | Управление SSL |
| **9** | 📝 | **Sub Page** | Настройка подписочной страницы |
| **10** | ⬆️ | **Обновить скрипт** | Pull последней версии |
| **11** | 💀 | **Удалить** | Полное удаление с подтверждением |

---

## 🐛 Что исправлено в v2.1.0

| # | Было (v2.0.0) | Стало |
|---|---|---|
| 1 | `DATABASE_URL` содержал литерал `***` → бэкенд не мог подключиться к БД | Реальный пароль, совпадает с `POSTGRES_PASSWORD` |
| 2 | «Авто-создание админа» вызывало несуществующую CLI-команду и печатало нерабочий пароль | Убрано. Первый зарегистрированный пользователь = супер-админ (как в Remnawave). Сброс: `docker exec -it remnawave cli` |
| 3 | `SUB_PUBLIC_DOMAIN` пустой без sub-page → ломались ссылки подписок | `panel.domain/api/sub` по умолчанию |
| 4 | Все ошибки `docker compose` / `apt` глотались спиннером | Каждый шаг проверяет exit-code, лог в `/var/log/remnawave-installer.log` |
| 5 | Caddy стартовал до создания сети → гонка | Проверка `docker network inspect` перед Caddy |
| 6 | `ss` не устанавливался → проверка портов молча проходила | `iproute2` в зависимостях |
| 7 | Меню обещало 11 опций, реализовано 5 | Реализованы все 11: update, restart, logs, certs, sub-page token, self-update |
| 8 | Настройки не сохранялись между запусками | `/opt/remnawave/.installer.conf` |
| 9 | `curl \| bash` не мог читать ввод | stdin переподключается к `/dev/tty` |
| 10 | Без валидации доменов/email | Проверка формата, DNS vs публичный IP сервера |
| 11 | Caddy без email для ACME, без HTTP/3 | `email` в глобальном блоке, `443/udp` |
| 12 | Повторный запуск затирал `.env` (новые пароли → БД недоступна) | Секреты сохраняются, обновляются только домены |
| 13 | Node: `SECRET_KEY` в открытом виде в compose | Вынесен в `.env` (chmod 600) |
| 14 | Uninstall удалял бэкапы вместе с `/opt/remnawave` | Бэкапы копируются в `/root/remnawave-backups-*` |

Compose-файлы панели, Caddy, sub-page и ноды соответствуют актуальным `docker-compose-prod.yml` из upstream-репозиториев Remnawave.

---

## 🏗️ Архитектура

```
    🌐 Интернет
         │
         ▼
    ┌─────────────────────────────────────────────────┐
    │              Docker Bridge Network               │
    │                                                  │
    │  ┌──────────┐    ┌──────────┐    ┌──────────┐  │
    │  │  CADDY   │───▶│ REMNAWAVE│───▶│    DB     │  │
    │  │  :80     │    │  :3000   │    │ postgres  │  │
    │  │  :443    │    │  :3001   │    │ 18.4      │  │
    │  └──────────┘    └──────────┘    └──────────┘  │
    │       │                │                        │
    │       │          ┌──────────┐                   │
    │       │          │  VALKEY  │                   │
    │       │          │ 9-alpine │                   │
    │       │          │ (socket) │                   │
    │       │          └──────────┘                   │
    │       │                                         │
    │       ▼                                         │
    │  ┌──────────┐                                   │
    │  │ SUB PAGE │                                   │
    │  │  :3010   │                                   │
    │  └──────────┘                                   │
    └─────────────────────────────────────────────────┘
              │
              ▼  (отдельный сервер)
    ┌──────────────────┐
    │  REMNAWAVE NODE  │
    │  host network    │
    │  port 2222       │
    │  Xray Core       │
    └──────────────────┘
```

---

## ⚡ Быстрый старт

### Одна команда — и всё установлено

```bash
curl -Ls https://raw.githubusercontent.com/Nurulaev/install-remnawave/main/install_remnawave.sh | sudo bash
```

### Или скачай вручную

```bash
git clone https://github.com/Nurulaev/install-remnawave.git
cd install-remnawave
sudo bash install_remnawave.sh
```

### CLI команды

```bash
sudo bash install_remnawave.sh install      # 🚀 установка панели
sudo bash install_remnawave.sh node         # 🌍 установка ноды
sudo bash install_remnawave.sh status       # 📊 статус
sudo bash install_remnawave.sh update       # 🔄 обновить образы
sudo bash install_remnawave.sh restart      # 🔁 перезапуск
sudo bash install_remnawave.sh logs         # 📋 логи
sudo bash install_remnawave.sh backup       # 💾 бэкап
sudo bash install_remnawave.sh certs        # 🔒 сертификаты
sudo bash install_remnawave.sh subpage      # 📝 API-токен sub-page
sudo bash install_remnawave.sh self-update  # ⬆️  обновить скрипт
sudo bash install_remnawave.sh uninstall    # 💀 удаление
sudo bash install_remnawave.sh --help       # 📖 помощь
```

---

## 📦 Что устанавливается

| Сервис | Контейнер | Образ | Порт |
|--------|-----------|-------|------|
| 🔧 Backend | `remnawave` | `remnawave/backend:3` | 3000, 3001 |
| 🗄️ Database | `remnawave-db` | `postgres:18.4` | internal |
| ⚡ Cache | `remnawave-redis` | `valkey/valkey:9-alpine` | socket |
| 🌐 Proxy | `caddy` | `caddy:2` | 80, 443, 443/udp |
| 📄 Sub Page | `remnawave-subscription-page` | `remnawave/subscription-page:latest` | 3010 |
| 🌍 Node | `remnanode` | `remnawave/node:latest` | 2222 |

---

## 🗂️ Структура файлов

```
/opt/remnawave/
├── 📄 .env                        # секреты (chmod 600)
├── 📄 .installer.conf             # домены/настройки установщика
├── 📄 docker-compose.yml          # панель + postgres + valkey
├── 📂 caddy/
│   ├── 📄 Caddyfile               # reverse proxy
│   └── 📄 docker-compose.yml      # Caddy 2
├── 📂 subscription/
│   ├── 📄 .env                    # TRUST_PROXY=1
│   └── 📄 docker-compose.yml
└── 📂 backups/
    └── 📦 remnawave_backup_*.tar.gz
```

---

## 🔧 Требования

| Требование | Минимум | Рекомендация |
|------------|---------|--------------|
| 🖥️ ОС | Debian 11+ / Ubuntu 20+ | Debian 12 / Ubuntu 22 |
| 👤 Пользователь | root | root |
| 💾 RAM | 1 GB | 2+ GB |
| 💿 Диск | 10 GB | 20+ GB |
| 🌐 Сеть | Публичный IP + домены | 2 домена (panel + sub) |
| 🐳 Docker | автоустановка | последняя версия |

---

## ⚙️ Конфигурация

> **DNS:** создайте A-записи для панели и подписочной страницы **до** запуска установщика.

> **SSL:** Let's Encrypt выдаётся автоматически Caddy (нужен email).

> **Первый вход:** откройте `https://panel.domain` — первый зарегистрированный пользователь становится супер-админом. Забыли пароль: `docker exec -it remnawave cli` → Reset superadmin.

> **Sub-page:** после первого входа создайте токен (Remnawave Settings → API Tokens) и вставьте его через меню «9».

> **Нода:** после установки панели, создайте ноду через меню «2» или вручную:
> 1. Панель → Nodes → Management → Add Node
> 2. Скопируйте SECRET_KEY
> 3. Запустите `bash install_remnawave.sh node` на сервере ноды

---

## 📜 Лицензия

MIT License — свободно используйте.

Remnawave — собственная лицензия ([GitHub](https://github.com/remnawave)).

---

<div align="center">

```
    🐇 "Curiouser and curiouser!" — Alice
```

**⭐ Звезда репозитория, если помогло! ⭐**

[![Stargazers](https://img.shields.io/github/stars/Nurulaev/install-remnawave?style=social)](https://github.com/Nurulaev/install-remnawave/stargazers)

</div>