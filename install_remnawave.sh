#!/usr/bin/env bash
#
# ═══════════════════════════════════════════════════════════════════════════
#   remnawave-installer — установка панели Remnawave в btop-стиле
#   Публичная ссылка: curl -Ls https://raw.githubusercontent.com/Nurulaev/install-remnawave/main/install_remnawave.sh | bash
#   Логика взята из eGamesAPI/remnawave-reverse-proxy и переоформлена в TUI-стиль
# ═══════════════════════════════════════════════════════════════════════════

set -o pipefail

# ┌───────────────────────────────────────────────┐
# │ 0. ПАЛИТРА / ПАЛИТРА / ЦВЕТА                  │
# └───────────────────────────────────────────────┘
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_DIM="\033[2m"
C_BLINK="\033[5m"

# базовые цвета
C_BLACK="\033[30m";  C_RED="\033[31m";   C_GREEN="\033[32m"; C_YELLOW="\033[33m"
C_BLUE="\033[34m";   C_MAGENTA="\033[35m"; C_CYAN="\033[36m"; C_WHITE="\033[37m"
C_GRAY="\033[90m"

# яркие
C_BRED="\033[91m"; C_BGREEN="\033[92m"; C_BYELLOW="\033[93m"; C_BBLUE="\033[94m"
C_BMAGENTA="\033[95m"; C_BCYAN="\033[96m"; C_BWHITE="\033[97m"

# фон
BG_RED="\033[41m"; BG_GREEN="\033[42m"; BG_YELLOW="\033[43m"; BG_BLUE="\033[44m"
BG_MAGENTA="\033[45m"; BG_CYAN="\033[46m"; BG_BLACK="\033[40m"

# btop — фирменные цвета (тёмная тема)
G="\033[38;5;114m"        # green (mint)
Y="\033[38;5;214m"        # yellow
B="\033[38;5;111m"        # blue
M="\033[38;5;170m"        # purple/magenta
C="\033[38;5;117m"        # cyan
R="\033[38;5;203m"        # red
W="\033[38;5;255m"        # white
D="\033[38;5;241m"        # dim gray
O="\033[38;5;208m"        # orange

SCRIPT_VERSION="1.0.0-btop"
DIR="/opt/remnawave"

# ┌───────────────────────────────────────────────┐
# │ 1. ПЕРЕМЕННЫЕ ИНСТАЛЛЯЦИИ                     │
# └───────────────────────────────────────────────┘
PANEL_DOMAIN=""
SUBDOMAIN=""
NODE_DOMAIN=""
EMAIL=""
CF_API_TOKEN=""
CF_EMAIL=""
CF_ZONE=""
USE_CADDY=true
INSTALL_SUB_PAGE=true

# аккумулятор ошибок
declare -a _warnings=()

# ┌───────────────────────────────────────────────┐
# │ 2. УТИЛИТЫ ОТОБРАЖЕНИЯ (btop-стиль)          │
# └───────────────────────────────────────────────┘

# ── санитайзер: убирает ESC-коды из строк ──
_plain() { sed -r 's/\x1b\[[0-9;]*[a-zA-Z]//g'; }

# ── измерение "видимой" длины строки ──
_plen() { echo -n "$1" | _plain | wc -m; }

# ── горизонтальная линия с заголовком ══[ lbl ]══ ──
box_line() {
    local label="$1"; local width="${2:-60}"
    local lw; lw=$(_plen "$label")
    local half=$(( (width - lw - 4) / 2 ))
    [ "$half" -lt 1 ] && half=1
    local left right
    left=$(printf '═%.0s' $(seq 1 "$half"))
    right=$(printf '═%.0s' $(seq 1 $(( width - lw - 4 - half )) ))
    echo -e "${D}${left}${C_RESET} ${W}${label}${C_RESET} ${D}${right}${C_RESET}"
}

# ── рамка-бокс с заголовком (как окно в btop) ──
box() {
    local title="$1"; shift
    local color="${1:-$C}"  # цвет рамки
    local width="${2:-64}"
    local tlen; tlen=$(_plen "$title")
    local inner=$(( width - 2 ))
    # верхняя грань: ╭───[ title ]───╮
    local half=$(( (inner - tlen - 2) / 2 ))
    [ "$half" -lt 1 ] && half=1
    echo -e "${color}╭${C_RESET}${D}$(printf '─%.0s' $(seq 1 $half))${C_RESET} ${W}${title}${C_RESET} ${D}$(printf '─%.0s' $(seq 1 $((inner - tlen - 2 - half))))${C_RESET}${color}╮${C_RESET}"
    # тело (пустое, строки рисуют вызывающие)
}

# ── закрытие рамки ──
box_end() {
    local color="${1:-$C}"; local width="${2:-64}"
    echo -e "${color}╰${C_RESET}${D}$(printf '─%.0s' $(seq 1 $((width - 2))))${C_RESET}${color}╯${C_RESET}"
}

# ── заполненная строка внутри бокса: │ текст         │ ──
row() {
    local text="$1"; local color="${2:-$W}"; local width="${3:-62}"
    local tl; tl=$(_plen "$text")
    local pad=$(( width - tl - 2 ))
    [ "$pad" -lt 1 ] && pad=1
    echo -e "${C}│${C_RESET} ${color}${text}${C_RESET}$(printf ' %.0s' $(seq 1 $pad)) ${C}│${C_RESET}"
}

# ── статус-индикатор checkbox ──
ok()   { echo -e " ${G}[✔]${C_RESET} $*"; }
info() { echo -e " ${B}[•]${C_RESET} $*"; }
warn() { echo -e " ${Y}[!]${C_RESET} $*"; echo -e "       ${D}$*${C_RESET}"; _warnings+=("$*"); }
err()  { echo -e " ${R}[✘]${C_RESET} $*"; }

# ── прогресс-бар (btop style) ──
progress() {
    local cur="$1"; local total="$2"; local label="${3:-}"
    local width=32
    local pct=$(( cur * 100 / total ))
    local filled=$(( cur * width / total ))
    local i
    local bar=""
    local BLOCK_FULL="█"; local BLOCK_EMPTY="░"
    for (( i=0; i<width; i++ )); do
        if [ "$i" -lt "$filled" ]; then
            bar="${bar}${G}${BLOCK_FULL}${C_RESET}"
        else
            bar="${bar}${D}${BLOCK_EMPTY}${C_RESET}"
        fi
    done
    local right=$(( 100 - pct ))
    [ "$right" -lt 0 ] && right=0
    printf "\r  ${bar} ${G}%3d%%${C_RESET} ${D}%s${C_RESET}" "$pct" "$label"
    [ "$cur" -eq "$total" ] && printf "\n"
}

# ── анимированный спиннер ──
spin() {
    local pid=$1; local msg="$2"
    local f=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local i=0
    printf "  ${C}%s${C_RESET} ${W}%s${C_RESET}" "${f[0]}" "$msg"
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ${C}%s${C_RESET} ${W}%s${C_RESET}" "${f[$((i % ${#f[@]}))]}" "$msg"
        i=$((i + 1)); sleep 0.1
    done
    printf "\r  ${G}✔${C_RESET} ${W}%s${C_RESET}\033[K\n" "$msg"
}

# ── анимированный баннер (радуга по ASCII) ──
banner() {
    local art=(
        "  _ __ ___  _ __ ___  _ __   ___  _ __   "
        " | '_ \` _ \\| '_ \` _ \\| '_ \\ / _ \\| '_ \\  "
        " | | | | | | | | | | | |_) | (_) | | | | "
        " |_| |_| |_|_| |_| |_| .__/ \\___/|_| |_| "
        "                      |_|                "
    )
    local rain=("$G" "$C" "$B" "$M" "$Y" "$O")
    local k=0
    for line in "${art[@]}"; do
        printf "   "
        for (( i=0; i<${#line}; i++ )); do
            local ch="${line:$i:1}"
            if [ "$ch" == " " ]; then printf " "; else
                printf "${rain[$((k % 6))]}%s${C_RESET}" "$ch"
                k=$((k+1))
            fi
        done
        printf "\n"
    done
    printf "\n"
}

# ── экран "boot" как btop: прогресс по шагам ──
boot_screen() {
    banner
    box "SYSTEM" "$C" 64
    row "Проверка root-доступа"
    sleep 0.3
    row "Определение ОС (Debian/Ubuntu)"
    sleep 0.3
    row "Установка зависимостей (docker, compose, yq, jq)"
    sleep 0.3
    row "Развёртывание Remnawave Panel"
    sleep 0.3
    row ""
    progress 25 100 "init"
    sleep 0.4
    box_end "$C" 64
    echo ""
}

# ── меню в стиле btop: выбрать установку ──
show_main_menu() {
    clear
    banner
    echo -e "${D}   Remnawave Panel Installer · btop edition · v${SCRIPT_VERSION}${C_RESET}"
    echo -e "${D}   Логика: eGamesAPI/remnawave-reverse-proxy${C_RESET}"
    echo ""
    box_line "${W}ВЫБЕРИТЕ ДЕЙСТВИЕ${C_RESET}" 60
    echo ""
    echo -e "  ${G}1${C_RESET}. Установить Remnawave (панель + нода + подписка)"
    echo -e "  ${G}2${C_RESET}. Переустановить панель/ноду"
    echo -e "  ${G}3${C_RESET}. Управление панелью/нодой"
    echo ""
    echo -e "  ${G}4${C_RESET}. Установить случайный шаблон"
    echo -e "  ${G}5${C_RESET}. Пользовательские шаблоны (legiz)"
    echo -e "  ${G}6${C_RESET}. WARP Native"
    echo -e "  ${G}7${C_RESET}. Резервное копирование / восстановление"
    echo ""
    echo -e "  ${G}8${C_RESET}. Управление IPv6"
    echo -e "  ${G}9${C_RESET}. Управление сертификатами домена"
    echo ""
    echo -e "  ${G}10${C_RESET}. Проверить обновления"
    echo -e "  ${G}11${C_RESET}. Удалить скрипт"
    echo -e "  ${G}0${C_RESET}. Выход"
    echo ""
    echo -e "  ${D}Быстрый старт: ${G}remnawave_reverse${C_RESET}${D} или установить: ${G}install${C_RESET}${D}${C_RESET}"
    echo ""
}

# ── чтение ввода с подсказкой ──
rain() {
    local prompt="$1"; local var="$2"
    read -rp "  ${G}?>${C_RESET} ${W}${prompt}${C_RESET} " "$var"
}

# ┌───────────────────────────────────────────────┐
# │ 3. ПРОВЕРКА СИСТЕМЫ                          │
# └───────────────────────────────────────────────┘
require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        err "Запустите скрипт от root (sudo bash install_remnawave.sh)"
        exit 1
    fi
    ok "Root-доступ подтверждён"
}

detect_os() {
    if ! command -v apt-get >/dev/null 2>&1; then
        err "Поддерживаются только Debian/Ubuntu (apt). Обнаружена другая система."
        exit 1
    fi
    ok "ОС: $(. /etc/os-release && echo "$PRETTY_NAME")"
}

# ┌───────────────────────────────────────────────┐
# │ 4. УСТАНОВКА ЗАВИСИМОСТЕЙ                    │
# └───────────────────────────────────────────────┘
install_deps() {
    info "Обновление пакетов..."
    (apt-get update -y >/dev/null 2>&1) &
    spin $! "apt-get update"
    (apt-get install -y curl wget jq unzip >/dev/null 2>&1) &
    spin $! "Установка базовых пакетов"

    # docker
    if ! command -v docker >/dev/null 2>&1; then
        info "Docker не найден — устанавливаю..."
        (curl -fsSL https://get.docker.com | bash >/dev/null 2>&1) &
        spin $! "get.docker.com"
    fi
    ok "Docker: $(docker --version 2>/dev/null | _plain)"

    # compose plugin
    if ! docker compose version >/dev/null 2>&1; then
        info "Docker Compose plugin отсутствует — устанавливаю..."
        (apt-get install -y docker-compose-plugin >/dev/null 2>&1) &
        spin $! "docker-compose-plugin"
    fi
    ok "Compose: $(docker compose version 2>/dev/null | _plain)"

    # yq
    if ! command -v yq >/dev/null 2>&1; then
        info "yq отсутствует — устанавливаю..."
        (wget -q https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq && chmod +x /usr/bin/yq >/dev/null 2>&1) &
        spin $! "yq"
    fi
    ok "yq: $(yq --version 2>/dev/null | _plain)"
}

# ┌───────────────────────────────────────────────┐
# │ 5. СБОР ДАННЫХ                                │
# └───────────────────────────────────────────────┘
collect_domains() {
    box "КОНФИГУРАЦИЯ ДОМЕНОВ" "$C" 64
    echo ""
    row "1) Домен панели (например panel.example.com)"
    row "2) Домен подписочной страницы (sub.example.com)"
    row "3) Домен ноды (node.example.com — опционально)"
    echo ""
    box_end "$C" 64
    echo ""
    rain "Введите домен панели:" PANEL_DOMAIN
    [ -z "$PANEL_DOMAIN" ] && { err "Домен обязателен"; exit 1; }

    rain "Введите домен подписочной страницы (или пусто = пропустить):" SUBDOMAIN
    if [ -z "$SUBDOMAIN" ]; then INSTALL_SUB_PAGE=false; else INSTALL_SUB_PAGE=true; fi

    rain "Введите домен ноды (или пусто = root-домен):" NODE_DOMAIN

    rain "Email для SSL (Let's Encrypt / Cloudflare):" EMAIL

    echo ""
    info "Проверяю DNS для доменов..."
    for d in "$PANEL_DOMAIN" "$SUBDOMAIN"; do
        [ -z "$d" ] && continue
        local ip
        ip=$(getent hosts "$d" 2>/dev/null | awk '{print $1}' | head -1)
        if [ -n "$ip" ]; then
            ok "$d → $ip"
        else
            warn "DNS для $d не найден — создайте A-запись, указывающую на этот сервер"
        fi
    done
}

# ┌───────────────────────────────────────────────┐
# │ 6. ГЕНЕРАЦИЯ .env                             │
# └───────────────────────────────────────────────┘
gen_secret() { openssl rand -hex 32 2>/dev/null || head -c64 /dev/urandom | od -An -tx1 | tr -d ' \n'; }

write_env() {
    mkdir -p "$DIR"
    local db_pass api_pass metrics_pass
    db_pass=$(gen_secret); api_pass=$(gen_secret); metrics_pass=$(gen_secret)

    info "Генерация секретов..."
    progress 30 100 "APP_SECRET, DATABASE_URL, токены"
    cat > "$DIR/.env" <<EOF
### Remnawave Panel ###
PANEL_DOMAIN=$PANEL_DOMAIN
FRONT_END_DOMAIN=*
SUB_PUBLIC_DOMAIN=$SUBDOMAIN

### API ###
API_INSTANCES=1
DATABASE_URL=postgresql://postgres:${db_pass}@remnawave-db:5432/postgres
REDIS_SOCKET=/var/run/valkey/valkey.sock

### Secrets ###
APP_SECRET=$(gen_secret)

### Prometheus ###
METRICS_USER=admin
METRICS_PASS=${metrics_pass}

### Telegram (опционально) ###
IS_TELEGRAM_NOTIFICATIONS_ENABLED=false

### Database container ###
POSTGRES_USER=postgres
POSTGRES_PASSWORD=${db_pass}
POSTGRES_DB=postgres
EOF
    progress 70 100 "запись .env"
    chmod 600 "$DIR/.env"
    progress 100 100 "готово"
    ok "Файл $DIR/.env создан"
}

# ┌───────────────────────────────────────────────┐
# │ 7. DOCKER-COMPOSE (панель + db + redis)      │
# └───────────────────────────────────────────────┘
write_compose() {
    info "Создание docker-compose.yml..."
    cat > "$DIR/docker-compose.yml" <<'EOF'
x-common: &common
  ulimits:
    nofile: { soft: 1048576, hard: 1048576 }
  restart: always
  networks: [remnawave-network]

x-logging: &logging
  logging:
    driver: json-file
    options: { max-size: 100m, max-file: "5" }

services:
  remnawave:
    image: remnawave/backend:3
    container_name: remnawave
    hostname: remnawave
    <<: [*common, *logging]
    env_file: .env
    volumes:
      - valkey-socket:/var/run/valkey
    ports:
      - 127.0.0.1:3000:3000
      - 127.0.0.1:3001:3001
    depends_on:
      remnawave-db: { condition: service_healthy }
      remnawave-redis: { condition: service_healthy }

  remnawave-db:
    image: postgres:16
    container_name: remnawave-db
    hostname: remnawave-db
    <<: [*common, *logging]
    env_file: .env
    environment:
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=${POSTGRES_DB}
      - TZ=UTC
    volumes:
      - remnawave-db-data:/var/lib/postgresql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 3s
      timeout: 3s
      retries: 30

  remnawave-redis:
    image: valkey/valkey:7-alpine
    container_name: remnawave-redis
    hostname: remnawave-redis
    <<: [*common, *logging]
    volumes:
      - valkey-socket:/var/run/valkey
    command: >
      valkey-server --save "" --appendonly no
      --unixsocket /var/run/valkey/valkey.sock
      --unixsocketperm 777 --port 0
    healthcheck:
      test: ["CMD-SHELL", "valkey-cli -s /var/run/valkey/valkey.sock ping || nc -z localhost 0"]
      interval: 3s
      timeout: 3s
      retries: 30

networks:
  remnawave-network:
    name: remnawave-network
    driver: bridge

volumes:
  remnawave-db-data:
    name: remnawave-db-data
  valkey-socket:
    name: valkey-socket
EOF
    ok "docker-compose.yml создан"
}

# ┌───────────────────────────────────────────────┐
# │ 8. CADDYFILE                                  │
# └───────────────────────────────────────────────┘
write_caddyfile() {
    mkdir -p "$DIR/caddy"
    local sub_part=""
    if [ "$INSTALL_SUB_PAGE" = "true" ] && [ -n "$SUBDOMAIN" ]; then
        sub_part=$(cat <<EOF
https://$SUBDOMAIN {
        encode
        reverse_proxy * http://remnawave-subscription-page:3010
}
EOF
        )
    fi

    cat > "$DIR/caddy/Caddyfile" <<EOF
https://$PANEL_DOMAIN {
        encode
        reverse_proxy * http://remnawave:3000
}
$sub_part
:443 {
    tls internal
    respond 204
}
EOF
    ok "Caddyfile создан"
}

# ┌───────────────────────────────────────────────┐
# │ 9. ПОДПИСОЧНАЯ СТРАНИЦА (опционально)        │
# └───────────────────────────────────────────────┘
write_sub_page() {
    [ "$INSTALL_SUB_PAGE" = "false" ] && { info "Подписочная страница пропущена"; return; }
    info "Подготовка подписочной страницы..."
    mkdir -p "$DIR/subscription"

    # собственный .env подписочной страницы (не путать с .env панели)
    cat > "$DIR/subscription/.env" <<EOF
APP_PORT=3010
REMNAWAVE_PANEL_URL=http://remnawave:3000
REMNAWAVE_API_TOKEN=PASTE_YOUR_API_TOKEN_HERE
CUSTOM_SUB_PREFIX=
MARZBAN_LEGACY_LINK_ENABLED=false
TRUST_PROXY=1
EOF
    warn "После первого запуска панели создайте API-токен (Settings → API Tokens) и вставьте его в $DIR/subscription/.env → REMNAWAVE_API_TOKEN, затем перезапустите подписочную страницу"

    cat > "$DIR/subscription/docker-compose.yml" <<'EOF'
services:
  remnawave-subscription-page:
    image: remnawave/subscription-page:latest
    container_name: remnawave-subscription-page
    hostname: remnawave-subscription-page
    restart: always
    env_file: .env
    ports:
      - "127.0.0.1:3010:3010"
    networks: [remnawave-network]

networks:
  remnawave-network:
    driver: bridge
    external: true
EOF
    ok "docker-compose подписочной страницы создан"
}

# ┌───────────────────────────────────────────────┐
# │ 10. ЗАПУСК                                    │
# └───────────────────────────────────────────────┘
start_services() {
    info "Запуск контейнеров панели..."
    (cd "$DIR" && docker compose up -d >/dev/null 2>&1) &
    spin $! "docker compose up -d (панель)"

    if [ "$INSTALL_SUB_PAGE" = "true" ]; then
        info "Запуск подписочной страницы..."
        (cd "$DIR/subscription" && docker compose up -d >/dev/null 2>&1) &
        spin $! "docker compose up -d (подписка)"
    fi

    info "Ожидание готовности панели (healthcheck)..."
    local tries=0
    while [ "$tries" -lt 60 ]; do
        if curl -sf http://127.0.0.1:3001/health >/dev/null 2>&1; then
            ok "Панель healthy"
            break
        fi
        tries=$((tries+1)); sleep 2
    done
}

# ┌───────────────────────────────────────────────┐
# │ 11. ИТОГОВЫЙ ЭКРАН (btop-сводка)             │
# └───────────────────────────────────────────────┘
summary() {
    clear
    banner
    box "УСТАНОВКА ЗАВЕРШЕНА" "$G" 64
    echo ""
    row "$(printf 'Панель:            %s ' "https://$PANEL_DOMAIN")" "$C" 62
    if [ "$INSTALL_SUB_PAGE" = "true" ]; then
        row "Подписка:          https://$SUBDOMAIN" "$C" 62
    fi
    row "Документация:      https://docs.rw" "$D" 62
    echo ""
    box_end "$G" 64
    echo ""

    if [ "${#_warnings[@]}" -gt 0 ]; then
        echo -e "  ${Y}┌─ Предупреждения ─────────────────────────────┐${C_RESET}"
        for w in "${_warnings[@]}"; do
            echo -e "  ${Y}│${C_RESET}  ${W}$w${C_RESET}"
        done
        echo -e "  ${Y}└───────────────────────────────────────────────┘${C_RESET}"
        echo ""
    fi

    echo -e "  ${Y}[!]${C_RESET} Учётные данные суперадмина выводятся при первом входе в панель."
    echo -e "  ${G}✔${C_RESET} Готово! Откройте панель в браузере."
    echo ""
}

# ┌───────────────────────────────────────────────┐
# │ 12. ГЛАВНАЯ ЛОГИКА                            │
# └───────────────────────────────────────────────┘
main_install() {
    require_root
    detect_os
    install_deps
    collect_domains
    write_env
    write_compose
    write_caddyfile
    write_sub_page
    start_services
    summary
}

# ┌───────────────────────────────────────────────┐
# │ 13. ДИСПЕТЧЕР                                 │
# └───────────────────────────────────────────────┘
case "${1:-}" in
    install|-i|--install)
        main_install
        ;;
    menu|-m|--menu)
        show_main_menu
        ;;
    version|-v|--version)
        echo "remnawave-installer v$SCRIPT_VERSION"
        ;;
    *)
        # автоопределение в ~/.bashrc или интерактивное меню
        if [ -t 0 ]; then
            main_install
        else
            show_main_menu
        fi
        ;;
esac
