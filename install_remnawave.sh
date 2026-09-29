#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
#   install_remnawave.sh  —  Remnawave Panel Installer  (btop TUI style)
#   Version 2.1.0
#   Usage:  sudo bash install_remnawave.sh [install|node|status|update|restart|logs|backup|certs|subpage|self-update|uninstall|menu|version|--help]
#   Quick:  bash <(curl -Ls https://raw.githubusercontent.com/Nurulaev/install-remnawave/main/install_remnawave.sh)
# ═══════════════════════════════════════════════════════════════════════════

set -o pipefail

# When piped (curl | bash) stdin is not a terminal — re-attach so prompts work.
if [ ! -t 0 ] && { exec 3< /dev/tty; } 2>/dev/null; then
    exec <&3 3<&-
fi

# ───────────────────────────────────────────────────────────────────────────
# 0. COLOR PALETTE (btop dark theme)
# ───────────────────────────────────────────────────────────────────────────
C_RESET=$'\033[0m'
C_BOLD=$'\033[1m'
C_DIM=$'\033[2m'

G=$'\033[38;5;114m'   # green (mint)
Y=$'\033[38;5;214m'   # yellow/amber
B=$'\033[38;5;111m'   # blue
M=$'\033[38;5;170m'   # purple/magenta
C=$'\033[38;5;117m'   # cyan
R=$'\033[38;5;203m'   # red
W=$'\033[38;5;255m'   # white
D=$'\033[38;5;241m'   # dim gray
O=$'\033[38;5;208m'   # orange

if [ -n "${NO_COLOR:-}" ] || [ ! -t 1 ]; then
    C_RESET="" C_BOLD="" C_DIM="" G="" Y="" B="" M="" C="" R="" W="" D="" O=""
fi

SCRIPT_VERSION="2.1.0"
SCRIPT_URL="https://raw.githubusercontent.com/Nurulaev/install-remnawave/main/install_remnawave.sh"
DIR="/opt/remnawave"
NODE_DIR="/opt/remnanode"
BACKUP_DIR="$DIR/backups"
STATE_FILE="$DIR/.installer.conf"
LOG_FILE="/var/log/remnawave-installer.log"
NETWORK="remnawave-network"

# ───────────────────────────────────────────────────────────────────────────
# 1. INSTALLATION VARIABLES (persisted to STATE_FILE)
# ───────────────────────────────────────────────────────────────────────────
PANEL_DOMAIN=""
SUBDOMAIN=""
NODE_DOMAIN=""
EMAIL=""
INSTALL_SUB_PAGE=true

declare -a _warnings=()

# ───────────────────────────────────────────────────────────────────────────
# 2. DISPLAY UTILITIES (btop-style)
# ───────────────────────────────────────────────────────────────────────────
_plain() { sed -r 's/\x1b\[[0-9;]*[a-zA-Z]//g'; }
_plen()  { printf '%s' "$1" | _plain | wc -m; }
_rep()   { local n="$1" ch="$2"; [ "$n" -gt 0 ] || return 0; printf "%${n}s" "" | sed "s/ /${ch}/g"; }

box_line() {
    local label="$1" width="${2:-60}"
    local lw; lw=$(_plen "$label")
    local half=$(( (width - lw - 2) / 2 )); [ "$half" -lt 1 ] && half=1
    local right=$(( width - lw - 2 - half )); [ "$right" -lt 1 ] && right=1
    printf '%s%s%s %s%s%s %s%s%s\n' "$D" "$(_rep "$half" '═')" "$C_RESET" "$W" "$label" "$C_RESET" "$D" "$(_rep "$right" '═')" "$C_RESET"
}

box() {
    local title="$1" color="${2:-$C}" width="${3:-64}"
    local tlen; tlen=$(_plen "$title")
    local inner=$(( width - 2 ))
    local half=$(( (inner - tlen - 2) / 2 )); [ "$half" -lt 1 ] && half=1
    local right=$(( inner - tlen - 2 - half )); [ "$right" -lt 0 ] && right=0
    printf '  %s╭%s%s%s%s %s%s%s %s%s%s%s╮%s\n' "$color" "$C_RESET" "$D" "$(_rep "$half" '─')" "$C_RESET" "$W" "$title" "$C_RESET" "$D" "$(_rep "$right" '─')" "$C_RESET" "$color" "$C_RESET"
}

box_end() {
    local color="${1:-$C}" width="${2:-64}"
    printf '  %s╰%s%s%s%s%s╯%s\n' "$color" "$C_RESET" "$D" "$(_rep $((width - 2)) '─')" "$C_RESET" "$color" "$C_RESET"
}

row() {
    local text="$1" color="${2:-$W}" width="${3:-64}"
    local tl; tl=$(_plen "$text")
    local pad=$(( width - tl - 4 )); [ "$pad" -lt 0 ] && pad=0
    printf '  %s│%s %s%s%s%*s %s│%s\n' "$C" "$C_RESET" "$color" "$text" "$C_RESET" "$pad" "" "$C" "$C_RESET"
}

kv() {
    local key="$1" val="$2" width="${3:-64}"
    local kl vl; kl=$(_plen "$key"); vl=$(_plen "$val")
    local kpad=$(( 18 - kl )); [ "$kpad" -lt 1 ] && kpad=1
    local pad=$(( width - 4 - kl - kpad - 2 - vl )); [ "$pad" -lt 0 ] && pad=0
    printf '  %s│%s %s%s%s%*s%s→%s %s%s%s%*s %s│%s\n' "$C" "$C_RESET" "$D" "$key" "$C_RESET" "$kpad" "" "$C" "$C_RESET" "$W" "$val" "$C_RESET" "$pad" "" "$C" "$C_RESET"
}

ok()   { printf '  %s[✔]%s %s\n' "$G" "$C_RESET" "$*"; }
info() { printf '  %s[•]%s %s\n' "$B" "$C_RESET" "$*"; }
warn() { printf '  %s[!]%s %s\n' "$Y" "$C_RESET" "$*"; _warnings+=("$*"); }
err()  { printf '  %s[✘]%s %s\n' "$R" "$C_RESET" "$*" >&2; }
die()  { err "$*"; exit 1; }

progress() {
    local cur="$1" total="$2" label="${3:-}" width=32
    [ "$total" -gt 0 ] || total=1
    local pct=$(( cur * 100 / total )); local filled=$(( cur * width / total ))
    local bar="" i
    for (( i=0; i<width; i++ )); do
        if [ "$i" -lt "$filled" ]; then bar="${bar}${G}█${C_RESET}"; else bar="${bar}${D}░${C_RESET}"; fi
    done
    printf '\r  %s %s%3d%%%s %s%s%s\033[K' "$bar" "$G" "$pct" "$C_RESET" "$D" "$label" "$C_RESET"
    [ "$cur" -ge "$total" ] && printf '\n'
}

# spin <pid> <msg> — waits for pid, returns its exit code
spin() {
    local pid=$1 msg="$2"
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏") i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf '\r  %s%s%s %s%s%s' "$C" "${frames[$((i % 10))]}" "$C_RESET" "$W" "$msg" "$C_RESET"
        i=$((i + 1)); sleep 0.1
    done
    local rc=0; wait "$pid" || rc=$?
    if [ "$rc" -eq 0 ]; then
        printf '\r  %s✔%s %s%s%s\033[K\n' "$G" "$C_RESET" "$W" "$msg" "$C_RESET"
    else
        printf '\r  %s✘%s %s%s%s %s(exit %s)%s\033[K\n' "$R" "$C_RESET" "$W" "$msg" "$C_RESET" "$D" "$rc" "$C_RESET"
    fi
    return "$rc"
}

# run <msg> <cmd...> — run command in background with spinner, log output, return rc
run() {
    local msg="$1"; shift
    { printf '\n### %s  $ %s\n' "$(date '+%F %T')" "$*"; } >> "$LOG_FILE" 2>/dev/null
    ( "$@" >> "$LOG_FILE" 2>&1 ) &
    spin $! "$msg"
}

# run_or_die <msg> <cmd...>
run_or_die() {
    local msg="$1"; shift
    if ! run "$msg" "$@"; then
        err "Step failed: $msg"
        err "Last log lines ($LOG_FILE):"
        tail -n 15 "$LOG_FILE" 2>/dev/null | sed 's/^/      /'
        exit 1
    fi
}

banner() {
    local art=(
        "  _ __ ___  _ __ ___  _ __   __ _ "
        " | '__/ _ \\| '_ \` _ \\| '_ \\ / _\` |"
        " | | |  __/| | | | | | | | | (_| |"
        " |_|  \\___||_| |_| |_|_| |_|\\__,_|"
    )
    local rain=("$G" "$C" "$B" "$M" "$Y" "$O") k=0 line i ch
    for line in "${art[@]}"; do
        printf '   '
        for (( i=0; i<${#line}; i++ )); do
            ch="${line:$i:1}"
            if [ "$ch" = " " ]; then printf ' '; else printf '%s%s%s' "${rain[$((k % 6))]}" "$ch" "$C_RESET"; k=$((k + 1)); fi
        done
        printf '\n'
    done
    echo ""
}

ask() {
    local prompt="$1" var="$2" default="${3:-}"
    local hint=""; [ -n "$default" ] && hint=" ${D}[${default}]${C_RESET}"
    read -rp "  ${G}?>${C_RESET} ${W}${prompt}${C_RESET}${hint} " "$var"
    [ -z "${!var}" ] && [ -n "$default" ] && printf -v "$var" '%s' "$default"
    return 0
}

header() {
    clear 2>/dev/null || true
    banner
    printf '  %sRemnawave Panel Installer · btop edition · v%s%s\n\n' "$D" "$SCRIPT_VERSION" "$C_RESET"
}

pause_menu() { echo ""; read -rp "  ${D}Press Enter to return to menu...${C_RESET}" _; }

confirm() {
    local ans
    printf '  %s[?]%s %s%s%s [y/N]: ' "$Y" "$C_RESET" "$W" "$1" "$C_RESET"
    read -r ans
    [[ "$ans" =~ ^[Yy]$ ]]
}

port_free() { ! ss -Hltn 2>/dev/null | awk '{print $4}' | grep -qE "[:.]${1}$"; }

gen_secret()   { openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'; }

valid_domain() { [[ "$1" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; }
valid_email()  { [[ "$1" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[a-zA-Z]{2,}$ ]]; }

# ───────────────────────────────────────────────────────────────────────────
# 3. STATE
# ───────────────────────────────────────────────────────────────────────────
save_state() {
    mkdir -p "$DIR"
    cat > "$STATE_FILE" <<EOF
# generated by install_remnawave.sh v${SCRIPT_VERSION}
PANEL_DOMAIN='${PANEL_DOMAIN}'
SUBDOMAIN='${SUBDOMAIN}'
NODE_DOMAIN='${NODE_DOMAIN}'
EMAIL='${EMAIL}'
INSTALL_SUB_PAGE='${INSTALL_SUB_PAGE}'
EOF
    chmod 600 "$STATE_FILE"
}

load_state() {
    # shellcheck disable=SC1090
    [ -f "$STATE_FILE" ] && . "$STATE_FILE"
    # Fallback: derive from .env of older installs
    if [ -z "$PANEL_DOMAIN" ] && [ -f "$DIR/.env" ]; then
        PANEL_DOMAIN=$(sed -n 's/^PANEL_DOMAIN=//p' "$DIR/.env")
        SUBDOMAIN=$(sed -n 's/^SUB_PUBLIC_DOMAIN=//p' "$DIR/.env" | grep -v '/api/sub' || true)
        [ -d "$DIR/subscription" ] && INSTALL_SUB_PAGE=true || INSTALL_SUB_PAGE=false
    fi
    return 0
}

installed() { [ -f "$DIR/docker-compose.yml" ] && [ -f "$DIR/.env" ]; }

# ───────────────────────────────────────────────────────────────────────────
# 4. SYSTEM CHECKS
# ───────────────────────────────────────────────────────────────────────────
require_root() {
    [ "$(id -u)" -eq 0 ] || die "Run this script as root: sudo bash install_remnawave.sh"
    ok "Root access confirmed"
}

detect_os() {
    command -v apt-get >/dev/null 2>&1 || die "Only Debian/Ubuntu supported (apt required). Detected: $(uname -s)"
    local os_name; os_name=$(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME")
    ok "OS: ${os_name:-$(uname -r)}"
}

require_docker() {
    command -v docker >/dev/null 2>&1 || die "Docker is not installed. Run option 1 (Install) first."
    docker info >/dev/null 2>&1 || die "Docker daemon is not running: systemctl start docker"
}

# ───────────────────────────────────────────────────────────────────────────
# 5. DEPENDENCIES
# ───────────────────────────────────────────────────────────────────────────
install_deps() {
    export DEBIAN_FRONTEND=noninteractive
    run_or_die "apt-get update" apt-get update -y
    run_or_die "Base packages (curl wget jq unzip openssl iproute2 ca-certificates)" \
        apt-get install -y curl wget jq unzip openssl iproute2 ca-certificates

    if ! command -v docker >/dev/null 2>&1; then
        info "Docker not found — installing via get.docker.com"
        run_or_die "Download get.docker.com" curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        run_or_die "Install Docker" sh /tmp/get-docker.sh
        rm -f /tmp/get-docker.sh
    fi
    ok "Docker: $(docker --version 2>/dev/null)"

    if ! docker compose version >/dev/null 2>&1; then
        run_or_die "docker-compose-plugin" apt-get install -y docker-compose-plugin
    fi
    ok "Compose: $(docker compose version 2>/dev/null)"

    systemctl enable --now docker >/dev/null 2>&1 || true
    docker info >/dev/null 2>&1 || die "Docker daemon failed to start — check: journalctl -u docker"
    ok "Docker daemon is active"
}

# ───────────────────────────────────────────────────────────────────────────
# 6. PORT CONFLICT CHECK
# ───────────────────────────────────────────────────────────────────────────
check_ports() {
    local conflict=false p
    for p in 80 443; do
        if ! port_free "$p"; then
            err "Port $p is already in use:"
            ss -Hltnp 2>/dev/null | grep -E "[:.]${p} " | head -3 | sed 's/^/      /'
            conflict=true
        fi
    done
    [ "$conflict" = false ] || { err "Free ports 80/443 (nginx/apache/caddy?) and re-run."; return 1; }
    ok "Ports 80 and 443 are free"
}

# ───────────────────────────────────────────────────────────────────────────
# 7. DOMAIN COLLECTION
# ───────────────────────────────────────────────────────────────────────────
public_ip() { curl -4 -fsS --max-time 5 https://ifconfig.me 2>/dev/null || curl -4 -fsS --max-time 5 https://api.ipify.org 2>/dev/null; }

collect_domains() {
    box "DOMAIN CONFIGURATION" "$C" 64
    row "1) Panel domain        (e.g. panel.example.com)"
    row "2) Subscription domain (e.g. sub.example.com — optional)"
    row "3) Email for Let's Encrypt SSL"
    box_end "$C" 64
    echo ""

    while :; do
        ask "Panel domain:" PANEL_DOMAIN
        valid_domain "$PANEL_DOMAIN" && break
        err "Invalid domain: '$PANEL_DOMAIN'"
    done

    while :; do
        ask "Subscription page domain (empty to skip):" SUBDOMAIN
        [ -z "$SUBDOMAIN" ] && { INSTALL_SUB_PAGE=false; break; }
        [ "$SUBDOMAIN" = "$PANEL_DOMAIN" ] && { err "Subscription domain must differ from panel domain"; continue; }
        valid_domain "$SUBDOMAIN" && { INSTALL_SUB_PAGE=true; break; }
        err "Invalid domain: '$SUBDOMAIN'"
    done

    while :; do
        ask "Email for Let's Encrypt SSL:" EMAIL
        valid_email "$EMAIL" && break
        err "Invalid email: '$EMAIL'"
    done

    echo ""
    info "Checking DNS resolution..."
    local myip d ip; myip=$(public_ip)
    [ -n "$myip" ] && info "This server's public IP: $myip"
    for d in "$PANEL_DOMAIN" "$SUBDOMAIN"; do
        [ -z "$d" ] && continue
        ip=$(getent ahostsv4 "$d" 2>/dev/null | awk '{print $1}' | head -1)
        if [ -z "$ip" ]; then
            warn "DNS for $d not resolved — create an A record → ${myip:-this server}"
        elif [ -n "$myip" ] && [ "$ip" != "$myip" ]; then
            warn "$d → $ip (differs from $myip; OK if behind Cloudflare proxy)"
        else
            ok "$d → $ip"
        fi
    done
}

# ───────────────────────────────────────────────────────────────────────────
# 8. GENERATE .env  (matches upstream .env.sample)
# ───────────────────────────────────────────────────────────────────────────
write_env() {
    mkdir -p "$DIR"
    info "Generating secrets..."
    local db_pass app_secret metrics_pass webhook_secret sub_public
    db_pass=$(gen_secret); app_secret=$(gen_secret); metrics_pass=$(gen_secret); webhook_secret=$(gen_secret)
    if [ "$INSTALL_SUB_PAGE" = true ]; then sub_public="$SUBDOMAIN"; else sub_public="${PANEL_DOMAIN}/api/sub"; fi
    progress 50 100 "writing .env"

    cat > "$DIR/.env" <<ENVEOF
### Remnawave Panel — generated by install_remnawave.sh v${SCRIPT_VERSION} ###

### APP ###
APP_PORT=3000
METRICS_PORT=3001

### API ###
API_INSTANCES=1

### DATABASE ###
DATABASE_URL="postgresql://postgres:${db_pass}@remnawave-db:5432/postgres"

### REDIS ###
REDIS_SOCKET=/var/run/valkey/valkey.sock

### Secrets ###
APP_SECRET=${app_secret}

### TELEGRAM NOTIFICATIONS ###
IS_TELEGRAM_NOTIFICATIONS_ENABLED=false
TELEGRAM_BOT_TOKEN=change_me
TELEGRAM_NOTIFY_USERS=change_me
TELEGRAM_NOTIFY_NODES=change_me
TELEGRAM_NOTIFY_CRM=change_me
TELEGRAM_NOTIFY_SERVICE=change_me
TELEGRAM_NOTIFY_TBLOCKER=change_me

### PANEL DOMAIN ###
PANEL_DOMAIN=${PANEL_DOMAIN}

### FRONT_END ###
FRONT_END_DOMAIN=*

### SUBSCRIPTION PUBLIC DOMAIN (no scheme, no trailing slash) ###
SUB_PUBLIC_DOMAIN=${sub_public}

### PROMETHEUS ###
METRICS_USER=admin
METRICS_PASS=${metrics_pass}

### WEBHOOK ###
WEBHOOK_ENABLED=false
WEBHOOK_URL=https://your-webhook-url.com/endpoint
WEBHOOK_SECRET_HEADER=${webhook_secret}

### NOTIFICATIONS ###
BANDWIDTH_USAGE_NOTIFICATIONS_ENABLED=false
BANDWIDTH_USAGE_NOTIFICATIONS_THRESHOLD=[60, 80]
NOT_CONNECTED_USERS_NOTIFICATIONS_ENABLED=false
NOT_CONNECTED_USERS_NOTIFICATIONS_AFTER_HOURS=[6, 24, 48]
EXPIRATION_NOTIFICATIONS_ENABLED=false
EXPIRATION_NOTIFICATIONS=[-72, -48, -24, 24]

### SHORT UUID ###
SHORT_UUID_METHOD=nanoid
SHORT_UUID_LENGTH=16

### PostgreSQL container ###
POSTGRES_USER=postgres
POSTGRES_PASSWORD=${db_pass}
POSTGRES_DB=postgres
ENVEOF

    chmod 600 "$DIR/.env"
    progress 100 100 "done"
    ok ".env created at $DIR/.env"
}

# ───────────────────────────────────────────────────────────────────────────
# 9. DOCKER-COMPOSE (panel + db + valkey) — mirrors upstream docker-compose-prod.yml
# ───────────────────────────────────────────────────────────────────────────
write_compose() {
    cat > "$DIR/docker-compose.yml" <<'COMPOSEEOF'
x-common: &common
  ulimits:
    nofile:
      soft: 1048576
      hard: 1048576
  restart: always
  networks:
    - remnawave-network

x-logging: &logging
  logging:
    driver: json-file
    options:
      max-size: 100m
      max-file: '5'

x-env: &env
  env_file: .env

services:
  remnawave:
    image: remnawave/backend:3
    container_name: remnawave
    hostname: remnawave
    <<: [*common, *logging, *env]
    volumes:
      - valkey-socket:/var/run/valkey
    ports:
      - 127.0.0.1:3000:${APP_PORT:-3000}
      - 127.0.0.1:3001:${METRICS_PORT:-3001}
    healthcheck:
      test: ['CMD-SHELL', 'curl -f http://localhost:${METRICS_PORT:-3001}/health']
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 30s
    depends_on:
      remnawave-db:
        condition: service_healthy
      remnawave-redis:
        condition: service_healthy

  remnawave-db:
    image: postgres:18.4
    container_name: remnawave-db
    hostname: remnawave-db
    shm_size: 512mb
    <<: [*common, *logging, *env]
    environment:
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=${POSTGRES_DB}
      - TZ=UTC
    ports:
      - 127.0.0.1:6767:5432
    volumes:
      - remnawave-db-data:/var/lib/postgresql
    healthcheck:
      test: ['CMD-SHELL', 'pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}']
      interval: 3s
      timeout: 10s
      retries: 3

  remnawave-redis:
    image: valkey/valkey:9-alpine
    container_name: remnawave-redis
    hostname: remnawave-redis
    <<: [*common, *logging]
    volumes:
      - valkey-socket:/var/run/valkey
    command: >
      valkey-server
      --save ""
      --appendonly no
      --maxmemory-policy noeviction
      --loglevel warning
      --unixsocket /var/run/valkey/valkey.sock
      --unixsocketperm 777
      --port 0
    healthcheck:
      test: ['CMD', 'valkey-cli', '-s', '/var/run/valkey/valkey.sock', 'ping']
      interval: 3s
      timeout: 3s
      retries: 3

networks:
  remnawave-network:
    name: remnawave-network
    driver: bridge
    external: false

volumes:
  remnawave-db-data:
    name: remnawave-db-data
    driver: local
    external: false
  valkey-socket:
    name: valkey-socket
    driver: local
    external: false
COMPOSEEOF
    ok "docker-compose.yml created"
}

# ───────────────────────────────────────────────────────────────────────────
# 10. CADDY
# ───────────────────────────────────────────────────────────────────────────
write_caddyfile() {
    mkdir -p "$DIR/caddy"
    local sub_block=""
    if [ "$INSTALL_SUB_PAGE" = true ] && [ -n "$SUBDOMAIN" ]; then
        sub_block="
https://${SUBDOMAIN} {
    encode gzip zstd
    reverse_proxy http://remnawave-subscription-page:3010
}"
    fi
    cat > "$DIR/caddy/Caddyfile" <<CADDYEOF
{
    email ${EMAIL}
}

https://${PANEL_DOMAIN} {
    encode gzip zstd
    reverse_proxy http://remnawave:3000
}
${sub_block}
CADDYEOF
    ok "Caddyfile created"
}

write_caddy_compose() {
    mkdir -p "$DIR/caddy"
    cat > "$DIR/caddy/docker-compose.yml" <<'CADDYCEOF'
services:
  caddy:
    image: caddy:2
    container_name: caddy
    hostname: caddy
    restart: always
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy-data:/data
      - caddy-config:/config
    networks:
      - remnawave-network
    ulimits:
      nofile:
        soft: 1048576
        hard: 1048576
    logging:
      driver: json-file
      options:
        max-size: 50m
        max-file: '3'

volumes:
  caddy-data:
    name: caddy-data
  caddy-config:
    name: caddy-config

networks:
  remnawave-network:
    name: remnawave-network
    external: true
CADDYCEOF
    ok "Caddy compose created"
}

# ───────────────────────────────────────────────────────────────────────────
# 11. SUBSCRIPTION PAGE (optional)
# ───────────────────────────────────────────────────────────────────────────
write_sub_page() {
    [ "$INSTALL_SUB_PAGE" = true ] || { info "Subscription page skipped (links served at ${PANEL_DOMAIN}/api/sub)"; return 0; }
    mkdir -p "$DIR/subscription"
    cat > "$DIR/subscription/.env" <<SUBEOF
APP_PORT=3010
REMNAWAVE_PANEL_URL=http://remnawave:3000
REMNAWAVE_API_TOKEN=
CUSTOM_SUB_PREFIX=
TRUST_PROXY=1
MARZBAN_LEGACY_LINK_ENABLED=false
SUBEOF
    chmod 600 "$DIR/subscription/.env"

    cat > "$DIR/subscription/docker-compose.yml" <<'SUBCEOF'
services:
  remnawave-subscription-page:
    image: remnawave/subscription-page:latest
    container_name: remnawave-subscription-page
    hostname: remnawave-subscription-page
    restart: always
    env_file:
      - .env
    ports:
      - '127.0.0.1:3010:3010'
    networks:
      - remnawave-network
    logging:
      driver: json-file
      options:
        max-size: 50m
        max-file: '3'

networks:
  remnawave-network:
    name: remnawave-network
    external: true
SUBCEOF
    ok "Subscription page compose created"
}

# ───────────────────────────────────────────────────────────────────────────
# 12. START / WAIT
# ───────────────────────────────────────────────────────────────────────────
compose() { local d="$1"; shift; docker compose --project-directory "$d" "$@"; }

start_services() {
    run_or_die "Pull panel images" compose "$DIR" pull
    run_or_die "docker compose up -d (panel)" compose "$DIR" up -d
    docker network inspect "$NETWORK" >/dev/null 2>&1 || die "Network $NETWORK was not created by compose"

    run_or_die "docker compose up -d (caddy)" compose "$DIR/caddy" up -d
    if [ "$INSTALL_SUB_PAGE" = true ]; then
        run_or_die "docker compose up -d (subscription)" compose "$DIR/subscription" up -d
    fi
    wait_healthy
}

wait_healthy() {
    info "Waiting for panel healthcheck (up to 3 min)..."
    local tries=0 max=90
    while [ "$tries" -lt "$max" ]; do
        if curl -sf http://127.0.0.1:3001/health >/dev/null 2>&1; then
            progress "$max" "$max" "healthy"; ok "Panel is healthy"; return 0
        fi
        if [ "$tries" -gt 10 ] && [ "$(docker inspect -f '{{.State.Status}}' remnawave 2>/dev/null)" = "exited" ]; then
            printf '\n'; err "Container 'remnawave' exited. Last logs:"
            docker logs --tail 20 remnawave 2>&1 | sed 's/^/      /'
            return 1
        fi
        progress "$tries" "$max" "waiting..."
        tries=$((tries + 1)); sleep 2
    done
    printf '\n'; warn "Panel healthcheck timed out — check: docker logs remnawave"
    return 1
}

# ───────────────────────────────────────────────────────────────────────────
# 13. SUMMARY
# ───────────────────────────────────────────────────────────────────────────
summary() {
    echo ""
    box "INSTALLATION COMPLETE" "$G" 64
    kv "Panel URL" "https://${PANEL_DOMAIN}"
    [ "$INSTALL_SUB_PAGE" = true ] && kv "Subscription" "https://${SUBDOMAIN}"
    kv "Install dir" "$DIR"
    kv "Env file" "$DIR/.env"
    kv "Caddyfile" "$DIR/caddy/Caddyfile"
    kv "Log" "$LOG_FILE"
    box_end "$G" 64
    echo ""
    box "NEXT STEPS" "$Y" 64
    row "1. Open https://${PANEL_DOMAIN} in a browser"
    row "   The FIRST registered user becomes super-admin."
    if [ "$INSTALL_SUB_PAGE" = true ]; then
        row "2. Panel → Settings → API Tokens → create token"
        row "3. Menu option 9 (Sub Page) → paste the token"
    fi
    row "Forgot password? docker exec -it remnawave cli"
    box_end "$Y" 64
    echo ""
    if [ "${#_warnings[@]}" -gt 0 ]; then
        box "WARNINGS" "$Y" 64
        local w; for w in "${_warnings[@]}"; do row "${w:0:58}" "$Y"; done
        box_end "$Y" 64
        echo ""
    fi
}

# ───────────────────────────────────────────────────────────────────────────
# 14. MAIN INSTALL FLOW
# ───────────────────────────────────────────────────────────────────────────
main_install() {
    header
    box "SYSTEM CHECK" "$C" 64
    require_root
    detect_os
    if installed; then
        box_end "$C" 64
        warn "Remnawave is already installed in $DIR"
        confirm "Re-run installation? Existing .env and DB volume are KEPT unless you uninstall first." || return 1
        load_state
    else
        box_end "$C" 64
    fi
    echo ""
    install_deps
    echo ""
    check_ports || { docker ps --format '{{.Names}}' 2>/dev/null | grep -qx caddy && info "(port used by our own caddy — continuing)" || exit 1; }
    echo ""
    collect_domains
    echo ""
    box "DEPLOY" "$C" 64
    if [ -f "$DIR/.env" ]; then
        info "Keeping existing .env (secrets preserved)"
        sed -i "s|^PANEL_DOMAIN=.*|PANEL_DOMAIN=${PANEL_DOMAIN}|" "$DIR/.env"
        if [ "$INSTALL_SUB_PAGE" = true ]; then sed -i "s|^SUB_PUBLIC_DOMAIN=.*|SUB_PUBLIC_DOMAIN=${SUBDOMAIN}|" "$DIR/.env"
        else sed -i "s|^SUB_PUBLIC_DOMAIN=.*|SUB_PUBLIC_DOMAIN=${PANEL_DOMAIN}/api/sub|" "$DIR/.env"; fi
    else
        write_env
    fi
    write_compose
    write_caddyfile
    write_caddy_compose
    write_sub_page
    save_state
    box_end "$C" 64
    echo ""
    start_services
    summary
}

# ═══════════════════════════════════════════════════════════════════════════
#  MENU ACTIONS
# ═══════════════════════════════════════════════════════════════════════════

# ── 2. NODE ──────────────────────────────────────────────────────────────
menu_install_node() {
    header
    box "INSTALL REMNANODE" "$B" 64
    row "Installs Remnawave Node on THIS server"
    row "(network_mode: host, NET_ADMIN for wireguard)"
    box_end "$B" 64
    echo ""
    require_root
    detect_os

    local node_secret="" node_port
    ask "SECRET_KEY (panel → Nodes → Add / docker exec -it remnawave cli):" node_secret
    [ -n "$node_secret" ] || { err "SECRET_KEY is required"; return 1; }
    ask "Node port:" node_port 2222
    [[ "$node_port" =~ ^[0-9]{2,5}$ ]] || { err "Invalid port"; return 1; }
    port_free "$node_port" || warn "Port $node_port is already in use"

    if ! command -v docker >/dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive
        run_or_die "apt-get update" apt-get update -y
        run_or_die "Base packages" apt-get install -y curl ca-certificates iproute2
        run_or_die "Download get.docker.com" curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        run_or_die "Install Docker" sh /tmp/get-docker.sh
        rm -f /tmp/get-docker.sh
        systemctl enable --now docker >/dev/null 2>&1 || true
    fi
    require_docker

    mkdir -p "$NODE_DIR" /var/log/remnanode
    cat > "$NODE_DIR/.env" <<NODEENV
NODE_PORT=${node_port}
SECRET_KEY=${node_secret}
NODEENV
    chmod 600 "$NODE_DIR/.env"
    cat > "$NODE_DIR/docker-compose.yml" <<'NODEEOF'
services:
  remnanode:
    image: remnawave/node:latest
    container_name: remnanode
    hostname: remnanode
    network_mode: host
    restart: always
    cap_add:
      - NET_ADMIN
    env_file:
      - .env
    ulimits:
      nofile:
        soft: 1048576
        hard: 1048576
    volumes:
      - /var/log/remnanode:/var/log/remnanode
    logging:
      driver: json-file
      options:
        max-size: 50m
        max-file: '3'
NODEEOF

    run_or_die "Pull remnawave/node" compose "$NODE_DIR" pull
    run_or_die "docker compose up -d (remnanode)" compose "$NODE_DIR" up -d
    echo ""
    box "NODE STATUS" "$G" 64
    kv "Image" "remnawave/node:latest"
    kv "Port" "$node_port"
    kv "Compose" "$NODE_DIR/docker-compose.yml"
    kv "Network" "host"
    kv "Status" "$(docker inspect -f '{{.State.Status}}' remnanode 2>/dev/null || echo unknown)"
    box_end "$G" 64
    info "Now add this server in panel → Nodes with port $node_port"
}

# ── 3. STATUS ────────────────────────────────────────────────────────────
menu_status() {
    header
    load_state
    box "SYSTEM STATUS" "$C" 64
    row "── Containers ──" "$B"
    local names="remnawave remnawave-db remnawave-redis caddy remnawave-subscription-page remnanode" n st
    local any=false
    for n in $names; do
        st=$(docker inspect -f '{{.State.Status}}{{if .State.Health}} / {{.State.Health.Status}}{{end}}' "$n" 2>/dev/null) || continue
        any=true
        case "$st" in running*healthy|running) kv "$n" "✔ $st" ;; *) kv "$n" "✘ $st" ;; esac
    done
    [ "$any" = true ] || row "  No Remnawave containers found"
    echo ""
    row "── Endpoints ──" "$B"
    curl -sf --max-time 3 http://127.0.0.1:3001/health >/dev/null 2>&1 && kv "Panel health" "✔ UP (:3001)" || kv "Panel health" "✘ DOWN"
    curl -sf --max-time 3 -o /dev/null http://127.0.0.1:3000 2>/dev/null   && kv "Panel web" "✔ UP (:3000)"   || kv "Panel web" "✘ DOWN"
    if [ -n "$PANEL_DOMAIN" ]; then
        local code; code=$(curl -s --max-time 8 -o /dev/null -w '%{http_code}' "https://${PANEL_DOMAIN}" 2>/dev/null)
        [[ "$code" =~ ^(200|30[0-9])$ ]] && kv "HTTPS panel" "✔ $code" || kv "HTTPS panel" "✘ ${code:-no response}"
    fi
    if [ "$INSTALL_SUB_PAGE" = true ]; then
        curl -sf --max-time 3 -o /dev/null http://127.0.0.1:3010 2>/dev/null && kv "Subscription" "✔ UP (:3010)" || kv "Subscription" "✘ DOWN"
    fi
    echo ""
    row "── Listening ports ──" "$B"
    local p; for p in 80 443 3000 3001 3010 6767 2222; do
        port_free "$p" && kv "Port $p" "— free" || kv "Port $p" "✔ LISTENING"
    done
    echo ""
    row "── Resources ──" "$B"
    kv "Disk (/)" "$(df -h / 2>/dev/null | awk 'NR==2{print $3"/"$2" ("$5")"}')"
    kv "Memory" "$(LC_ALL=C free -h 2>/dev/null | awk 'NR==2{print $3"/"$2}')"
    kv "Docker" "$(docker system df --format '{{.Type}}: {{.Size}}' 2>/dev/null | paste -sd, - | cut -c1-40)"
    box_end "$C" 64
}

# ── 4. UPDATE ────────────────────────────────────────────────────────────
menu_update() {
    header
    box "UPDATE REMNAWAVE" "$G" 64
    row "Pulls latest images and recreates containers."
    row "Database volume is preserved."
    box_end "$G" 64
    echo ""
    require_root; require_docker
    load_state
    local updated=false d
    for d in "$DIR" "$DIR/caddy" "$DIR/subscription" "$NODE_DIR"; do
        [ -f "$d/docker-compose.yml" ] || continue
        updated=true
        run "Pull  $(basename "$d")" compose "$d" pull || warn "Pull failed for $d"
        run "Up    $(basename "$d")" compose "$d" up -d --remove-orphans || warn "Up failed for $d"
    done
    [ "$updated" = true ] || { err "Nothing installed."; return 1; }
    run "Prune old images" docker image prune -f
    [ -f "$DIR/docker-compose.yml" ] && wait_healthy
    ok "Update complete"
}

# ── 5. RESTART ───────────────────────────────────────────────────────────
menu_restart() {
    header
    box "RESTART SERVICES" "$Y" 64
    box_end "$Y" 64
    require_root; require_docker
    local d; for d in "$DIR" "$DIR/caddy" "$DIR/subscription" "$NODE_DIR"; do
        [ -f "$d/docker-compose.yml" ] || continue
        run "Restart $(basename "$d")" compose "$d" restart || warn "Restart failed for $d"
    done
    [ -f "$DIR/docker-compose.yml" ] && wait_healthy
}

# ── 6. LOGS ──────────────────────────────────────────────────────────────
menu_logs() {
    header
    box "LOGS" "$C" 64
    local list=() n i=1
    for n in $(docker ps -a --format '{{.Names}}' 2>/dev/null | grep -E '^(remnawave|remnawave-db|remnawave-redis|caddy|remnawave-subscription-page|remnanode)$'); do
        list+=("$n"); row "$i) $n"; i=$((i+1))
    done
    row "$i) installer log ($LOG_FILE)"
    box_end "$C" 64
    [ "${#list[@]}" -gt 0 ] || [ -f "$LOG_FILE" ] || { err "Nothing to show"; return 1; }
    local choice lines
    ask "Choice:" choice 1
    ask "Lines:" lines 100
    [[ "$lines" =~ ^[0-9]+$ ]] || lines=100
    echo ""
    if [ "$choice" = "$i" ]; then
        tail -n "$lines" "$LOG_FILE" 2>/dev/null || err "No log yet"
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#list[@]}" ]; then
        docker logs --tail "$lines" "${list[$((choice-1))]}" 2>&1
    else
        err "Invalid choice"
    fi
}

# ── 7. BACKUP ────────────────────────────────────────────────────────────
menu_backup() {
    header
    box "BACKUP PANEL DATA" "$Y" 64
    row "pg_dumpall + all config files → tar.gz"
    row "Destination: $BACKUP_DIR/"
    box_end "$Y" 64
    echo ""
    require_root; require_docker
    installed || { err "Remnawave is not installed"; return 1; }
    confirm "Proceed with backup?" || { info "Cancelled"; return 0; }

    mkdir -p "$BACKUP_DIR"
    local ts tmpdir; ts=$(date +%Y%m%d_%H%M%S); tmpdir=$(mktemp -d)
    info "Dumping PostgreSQL..."
    if docker exec remnawave-db pg_dumpall -U postgres > "$tmpdir/pgdump.sql" 2>>"$LOG_FILE" && [ -s "$tmpdir/pgdump.sql" ]; then
        ok "Database dump: $(du -h "$tmpdir/pgdump.sql" | cut -f1)"
    else
        rm -rf "$tmpdir"; err "Database dump failed — is remnawave-db running?"; return 1
    fi
    mkdir -p "$tmpdir/remnawave"
    cp "$DIR/.env" "$DIR/docker-compose.yml" "$tmpdir/remnawave/" 2>/dev/null
    [ -f "$STATE_FILE" ] && cp "$STATE_FILE" "$tmpdir/remnawave/"
    [ -d "$DIR/caddy" ] && cp -r "$DIR/caddy" "$tmpdir/remnawave/"
    [ -d "$DIR/subscription" ] && cp -r "$DIR/subscription" "$tmpdir/remnawave/"
    ok "Config files copied"

    local file="$BACKUP_DIR/remnawave_backup_${ts}.tar.gz"
    if tar -czf "$file" -C "$tmpdir" . 2>>"$LOG_FILE"; then
        chmod 600 "$file"
        box "BACKUP COMPLETE" "$G" 64
        kv "File" "$file"
        kv "Size" "$(du -h "$file" | cut -f1)"
        box_end "$G" 64
        info "Restore DB: tar -xzOf <file> ./pgdump.sql | docker exec -i remnawave-db psql -U postgres"
    else
        err "Tarball creation failed"
    fi
    rm -rf "$tmpdir"
}

# ── 8. CERTIFICATES ──────────────────────────────────────────────────────
menu_certs() {
    header
    load_state
    box "SSL CERTIFICATES (Caddy / Let's Encrypt)" "$M" 64
    box_end "$M" 64
    require_docker
    docker ps --format '{{.Names}}' | grep -qx caddy || { err "Caddy container is not running"; return 1; }
    echo ""
    info "Certificates stored in caddy-data volume:"
    docker exec caddy sh -c 'find /data/caddy/certificates -name "*.crt" 2>/dev/null' | sed 's|.*/||; s/\.crt$//' | sed 's/^/      • /'
    local d; for d in "$PANEL_DOMAIN" "$SUBDOMAIN"; do
        [ -n "$d" ] || continue
        local exp; exp=$(echo | openssl s_client -servername "$d" -connect "${d}:443" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
        [ -n "$exp" ] && ok "$d expires: $exp" || warn "$d: no live certificate (DNS/ports?)"
    done
    echo ""
    box "ACTIONS" "$M" 64
    row "1) Reload Caddyfile (after manual edit)"
    row "2) Force re-issue (restart Caddy)"
    row "3) Show Caddy log (last 50 lines)"
    row "0) Back"
    box_end "$M" 64
    local c; ask "Choice:" c 0
    case "$c" in
        1) run "caddy reload" docker exec caddy caddy reload --config /etc/caddy/Caddyfile ;;
        2) run "Restart caddy" docker restart caddy ;;
        3) docker logs --tail 50 caddy 2>&1 ;;
    esac
}

# ── 9. SUBSCRIPTION PAGE ─────────────────────────────────────────────────
menu_subpage() {
    header
    load_state
    box "SUBSCRIPTION PAGE" "$B" 64
    if [ "$INSTALL_SUB_PAGE" != true ] || [ ! -f "$DIR/subscription/.env" ]; then
        row "Not installed. Subscriptions are served at:" "$Y"
        row "  https://${PANEL_DOMAIN:-<panel>}/api/sub" "$Y"
        box_end "$B" 64
        return 0
    fi
    local cur; cur=$(sed -n 's/^REMNAWAVE_API_TOKEN=//p' "$DIR/subscription/.env")
    kv "Domain" "https://${SUBDOMAIN}"
    kv "API token" "$([ -n "$cur" ] && echo "set (${cur:0:8}…)" || echo "✘ NOT SET")"
    kv "Env" "$DIR/subscription/.env"
    box_end "$B" 64
    echo ""
    info "Create a token in panel → Remnawave Settings → API Tokens"
    local tok; ask "Paste API token (empty = keep current):" tok
    [ -n "$tok" ] || return 0
    require_root; require_docker
    sed -i "s|^REMNAWAVE_API_TOKEN=.*|REMNAWAVE_API_TOKEN=${tok}|" "$DIR/subscription/.env"
    ok "Token saved"
    run "Recreate subscription page" compose "$DIR/subscription" up -d --force-recreate
    sleep 3
    curl -sf --max-time 5 -o /dev/null http://127.0.0.1:3010 && ok "Subscription page responds on :3010" || warn "No response on :3010 yet — check logs (menu 6)"
}

# ── 10. SELF-UPDATE ──────────────────────────────────────────────────────
menu_self_update() {
    header
    box "UPDATE INSTALLER SCRIPT" "$C" 64
    kv "Current" "v$SCRIPT_VERSION"
    box_end "$C" 64
    local tmp; tmp=$(mktemp)
    if ! curl -fsSL --max-time 20 "$SCRIPT_URL" -o "$tmp"; then rm -f "$tmp"; err "Download failed"; return 1; fi
    bash -n "$tmp" 2>/dev/null || { rm -f "$tmp"; err "Downloaded script has syntax errors — aborted"; return 1; }
    local new; new=$(sed -n 's/^SCRIPT_VERSION="\(.*\)"/\1/p' "$tmp" | head -1)
    kv "Latest" "v${new:-?}"
    if [ "$new" = "$SCRIPT_VERSION" ]; then ok "Already up to date"; rm -f "$tmp"; return 0; fi
    local self="${BASH_SOURCE[0]}"
    if [ -f "$self" ] && [ -w "$self" ]; then
        cp "$tmp" "$self" && chmod +x "$self" && ok "Updated $self → v$new. Restart the script."
    else
        mkdir -p "$DIR" && cp "$tmp" "$DIR/install_remnawave.sh" && ok "Saved to $DIR/install_remnawave.sh (running from pipe)"
    fi
    rm -f "$tmp"
}

# ── 11. UNINSTALL ────────────────────────────────────────────────────────
menu_uninstall() {
    header
    box "UNINSTALL REMNAWAVE" "$R" 64
    row "Removes ALL containers, volumes (DATABASE!) and configs" "$R"
    row "in $DIR and $NODE_DIR. IRREVERSIBLE." "$R"
    box_end "$R" 64
    echo ""
    require_root
    local c; printf '  %s[?]%s Type %sDELETE%s to confirm: ' "$R" "$C_RESET" "$R" "$C_RESET"; read -r c
    [ "$c" = "DELETE" ] || { info "Cancelled"; return 0; }
    if [ -d "$BACKUP_DIR" ] && ls "$BACKUP_DIR"/*.tar.gz >/dev/null 2>&1; then
        local keep="/root/remnawave-backups-$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$keep" && cp "$BACKUP_DIR"/*.tar.gz "$keep"/ && ok "Backups preserved in $keep"
    fi
    if command -v docker >/dev/null 2>&1; then
        local d; for d in "$DIR/subscription" "$DIR/caddy" "$DIR" "$NODE_DIR"; do
            [ -f "$d/docker-compose.yml" ] || continue
            run "Remove $(basename "$d")" compose "$d" down -v --remove-orphans || true
        done
        docker network rm "$NETWORK" >/dev/null 2>&1 || true
    fi
    rm -rf "$DIR" "$NODE_DIR"
    ok "Removed $DIR and $NODE_DIR (Docker itself kept)"
}

# ───────────────────────────────────────────────────────────────────────────
# MAIN MENU
# ───────────────────────────────────────────────────────────────────────────
show_main_menu() {
    while true; do
        header
        load_state
        local st="not installed"
        installed && st="installed · ${PANEL_DOMAIN:-?}"
        box_line "CHOOSE ACTION" 60
        printf '  %s%s%s\n\n' "$D" "$st" "$C_RESET"
        printf '  %s 1%s  🚀 Install Remnawave Panel\n'     "$G" "$C_RESET"
        printf '  %s 2%s  🌍 Install Remnanode\n'           "$B" "$C_RESET"
        printf '  %s 3%s  📊 Status\n'                      "$C" "$C_RESET"
        printf '  %s 4%s  🔄 Update (pull images)\n'        "$G" "$C_RESET"
        printf '  %s 5%s  🔁 Restart services\n'            "$Y" "$C_RESET"
        printf '  %s 6%s  📋 Logs\n'                        "$C" "$C_RESET"
        printf '  %s 7%s  💾 Backup\n'                      "$Y" "$C_RESET"
        printf '  %s 8%s  🔒 Certificates\n'                "$M" "$C_RESET"
        printf '  %s 9%s  📝 Subscription page (API token)\n' "$B" "$C_RESET"
        printf '  %s10%s  ⬆️  Update this script\n'         "$D" "$C_RESET"
        printf '  %s11%s  💀 Uninstall everything\n'        "$R" "$C_RESET"
        printf '  %s 0%s  Exit\n\n'                         "$D" "$C_RESET"
        local choice; ask "Your choice:" choice
        case "$choice" in
            1)  main_install;      pause_menu ;;
            2)  menu_install_node; pause_menu ;;
            3)  menu_status;       pause_menu ;;
            4)  menu_update;       pause_menu ;;
            5)  menu_restart;      pause_menu ;;
            6)  menu_logs;         pause_menu ;;
            7)  menu_backup;       pause_menu ;;
            8)  menu_certs;        pause_menu ;;
            9)  menu_subpage;      pause_menu ;;
            10) menu_self_update;  pause_menu ;;
            11) menu_uninstall;    pause_menu ;;
            0|q|exit) printf '  %s[!]%s Bye\n' "$Y" "$C_RESET"; exit 0 ;;
            *)  warn "Invalid choice: '$choice'"; sleep 1 ;;
        esac
    done
}

usage() {
    cat <<EOF
remnawave-installer v${SCRIPT_VERSION}

Usage: sudo bash install_remnawave.sh [command]

  install       Install panel (+Caddy, +subscription page)
  node          Install Remnanode on this server
  status        Containers / health / ports / resources
  update        Pull latest images and recreate
  restart       Restart all services
  logs          Show container logs
  backup        pg_dumpall + configs → tar.gz
  certs         SSL certificate info / reload
  subpage       Set subscription-page API token
  self-update   Update this script from GitHub
  uninstall     Remove everything (asks for DELETE)
  menu          Interactive menu (default)
  version       Print version
EOF
}

# ═══════════════════════════════════════════════════════════════════════════
#  DISPATCHER
# ═══════════════════════════════════════════════════════════════════════════
case "${1:-menu}" in
    install|-i|--install)       main_install ;;
    node|--node)                menu_install_node ;;
    status|--status)            menu_status ;;
    update|upgrade|--update)    menu_update ;;
    restart|--restart)          menu_restart ;;
    logs|--logs)                menu_logs ;;
    backup|--backup)            menu_backup ;;
    certs|ssl|--certs)          menu_certs ;;
    subpage|--subpage)          menu_subpage ;;
    self-update|--self-update)  menu_self_update ;;
    uninstall|--uninstall)      menu_uninstall ;;
    menu|-m|--menu)             show_main_menu ;;
    version|-v|--version)       echo "remnawave-installer v${SCRIPT_VERSION}" ;;
    help|-h|--help)             usage ;;
    *)                          err "Unknown command: $1"; usage; exit 1 ;;
esac
