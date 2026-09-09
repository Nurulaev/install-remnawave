#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
#   install-remnawave.sh  —  Remnawave Panel Installer  (btop TUI style)
#   Version 2.0.0
#   Usage:  sudo bash install_remnawave.sh [install|menu|version]
#   Quick:  curl -Ls https://raw.githubusercontent.com/user/install-remnawave/main/install_remnawave.sh | sudo bash
# ═══════════════════════════════════════════════════════════════════════════

set -o pipefail

# ───────────────────────────────────────────────────────────────────────────
# 0. COLOR PALETTE (btop dark theme)
# ───────────────────────────────────────────────────────────────────────────
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_DIM="\033[2m"

C_RED="\033[31m";    C_GREEN="\033[32m";  C_YELLOW="\033[33m"
C_BLUE="\033[34m";   C_MAGENTA="\033[35m"; C_CYAN="\033[36m"
C_WHITE="\033[37m";  C_GRAY="\033[90m"

C_BRED="\033[91m";   C_BGREEN="\033[92m"; C_BYELLOW="\033[93m"
C_BBLUE="\033[94m";  C_BMAGENTA="\033[95m"; C_BCYAN="\033[96m"

# btop signature colors
G="\033[38;5;114m"   # green (mint)
Y="\033[38;5;214m"   # yellow/amber
B="\033[38;5;111m"   # blue
M="\033[38;5;170m"   # purple/magenta
C="\033[38;5;117m"   # cyan
R="\033[38;5;203m"   # red
W="\033[38;5;255m"   # white
D="\033[38;5;241m"   # dim gray
O="\033[38;5;208m"   # orange
HI="\033[38;5;171m"  # hot pink

SCRIPT_VERSION="2.0.0"
DIR="/opt/remnawave"
BACKUP_DIR="$DIR/backups"

# ───────────────────────────────────────────────────────────────────────────
# 1. INSTALLATION VARIABLES
# ───────────────────────────────────────────────────────────────────────────
PANEL_DOMAIN=""
SUBDOMAIN=""
NODE_DOMAIN=""
EMAIL=""
INSTALL_SUB_PAGE=true
ADMIN_PASSWORD=""

# accumulator for warnings
declare -a _warnings=()

# ───────────────────────────────────────────────────────────────────────────
# 2. DISPLAY UTILITIES (btop-style)
# ───────────────────────────────────────────────────────────────────────────

# strip ANSI codes
_plain() { sed -r 's/\x1b\[[0-9;]*[a-zA-Z]//g'; }

# visible string length
_plen() { echo -n "$1" | _plain | wc -m; }

# ── horizontal line: ═══[ LABEL ]═══ ──
box_line() {
    local label="$1" width="${2:-60}"
    local lw; lw=$(_plen "$label")
    local half=$(( (width - lw - 4) / 2 ))
    [ "$half" -lt 1 ] && half=1
    local right=$(( width - lw - 4 - half ))
    printf "${D}"
    printf '═%.0s' $(seq 1 "$half")
    printf "${C_RESET} ${W}%s${C_RESET} ${D}" "$label"
    printf '═%.0s' $(seq 1 "$right")
    echo -e "${C_RESET}"
}

# ── btop box open: ╭──[ TITLE ]──╮ ──
box() {
    local title="$1"
    local color="${2:-$C}"
    local width="${3:-64}"
    local tlen; tlen=$(_plen "$title")
    local inner=$(( width - 2 ))
    local half=$(( (inner - tlen - 2) / 2 ))
    [ "$half" -lt 1 ] && half=1
    local right=$(( inner - tlen - 2 - half ))
    [ "$right" -lt 0 ] && right=0
    echo -e "${color}╭${C_RESET}${D}$(printf '─%.0s' $(seq 1 "$half"))${C_RESET} ${W}${title}${C_RESET} ${D}$(printf '─%.0s' $(seq 1 "$right"))${C_RESET}${color}╮${C_RESET}"
}

# ── btop box close ──
box_end() {
    local color="${1:-$C}" width="${2:-64}"
    echo -e "${color}╰${C_RESET}${D}$(printf '─%.0s' $(seq 1 $((width - 2))))${C_RESET}${color}╯${C_RESET}"
}

# ── row inside a box: │ text padded │ ──
row() {
    local text="$1" color="${2:-$W}" width="${3:-62}"
    local tl; tl=$(_plen "$text")
    local pad=$(( width - tl - 2 ))
    [ "$pad" -lt 1 ] && pad=1
    printf "${C}│${C_RESET} ${color}%s${C_RESET}" "$text"
    printf ' %.0s' $(seq 1 "$pad")
    echo -e " ${C}│${C_RESET}"
}

# ── status indicators ──
ok()   { echo -e "  ${G}[✔]${C_RESET} $*"; }
info() { echo -e "  ${B}[•]${C_RESET} $*"; }
warn() { echo -e "  ${Y}[!]${C_RESET} $*"; _warnings+=("$*"); }
err()  { echo -e "  ${R}[✘]${C_RESET} $*"; }

# ── colored two-column row: key → value ──
kv() {
    local key="$1" val="$2"
    printf "  ${C}│${C_RESET} ${D}%-22s${C_RESET} ${C}→${C_RESET} ${W}%s${C_RESET}" "$key" "$val"
    local padding=$(( 28 - ${#key} - ${#val} ))
    [ "$padding" -gt 0 ] && printf '%*s' "$padding" ""
    echo -e " ${C}│${C_RESET}"
}

# ── progress bar (btop style) ──
progress() {
    local cur="$1" total="$2" label="${3:-}"
    local width=32
    local pct=$(( cur * 100 / total ))
    local filled=$(( cur * width / total ))
    local bar=""
    local BLOCK_FULL="█" BLOCK_EMPTY="░"
    for (( i=0; i<width; i++ )); do
        if [ "$i" -lt "$filled" ]; then
            bar="${bar}${G}${BLOCK_FULL}${C_RESET}"
        else
            bar="${bar}${D}${BLOCK_EMPTY}${C_RESET}"
        fi
    done
    printf "\r  ${bar} ${G}%3d%%${C_RESET} ${D}%s${C_RESET}" "$pct" "$label"
    [ "$cur" -eq "$total" ] && printf "\n"
}

# ── animated spinner ──
spin() {
    local pid=$1 msg="$2"
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local i=0
    printf "  ${C}%s${C_RESET} ${W}%s${C_RESET}" "${frames[0]}" "$msg"
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ${C}%s${C_RESET} ${W}%s${C_RESET}" "${frames[$((i % 10))]}" "$msg"
        i=$((i + 1)); sleep 0.1
    done
    printf "\r  ${G}✔${C_RESET} ${W}%s${C_RESET}\033[K\n" "$msg"
}

# ── rainbow ASCII banner ──
banner() {
    local art=(
        "  _ __ ___  _ __ ___  _ __   ___  _ __   "
        " | '_ \\\` _ \\\| '_ \\\` _ \\\| '_ \\\ / _ \\\| '_ \\  "
        " | | | | | | | | | | | |_) | (_) | | | | "
        " |_| |_| |_|_| |_| |_| .__/ \\\\\\___/|_| |_| "
        "                      |_|                "
    )
    local rain=("$G" "$C" "$B" "$M" "$Y" "$O")
    local k=0
    for line in "${art[@]}"; do
        printf "   "
        for (( i=0; i<${#line}; i++ )); do
            local ch="${line:$i:1}"
            if [ "$ch" == " " ]; then
                printf " "
            else
                printf "${rain[$((k % 6))]}%s${C_RESET}" "$ch"
                k=$((k + 1))
            fi
        done
        printf "\n"
    done
    echo ""
}

# ── read input with colored prompt ──
ask() {
    local prompt="$1" var="$2"
    read -rp "  ${G}?>${C_RESET} ${W}${prompt}${C_RESET} " "$var"
}

# ── clear + banner + version header ──
header() {
    clear
    banner
    echo -e "  ${D}Remnawave Panel Installer · btop edition · v${SCRIPT_VERSION}${C_RESET}"
    echo ""
}

# ── pause and return to menu ──
pause_menu() {
    echo ""
    read -rp "  ${D}Press Enter to return to menu...${C_RESET}" _
}

# ── confirmation prompt (returns 0 for yes) ──
confirm() {
    local msg="$1"
    echo -en "  ${Y}[?]${C_RESET} ${W}${msg}${C_RESET} [y/N]: "
    read -r ans
    [[ "$ans" =~ ^[Yy]$ ]]
}

# ── port check (returns 0 if port is free) ──
port_free() {
    local port="$1"
    ! ss -tlnp 2>/dev/null | grep -q ":${port} " && \
    ! netstat -tlnp 2>/dev/null | grep -q ":${port} "
}

# ── hex secret generator ──
gen_secret() {
    openssl rand -hex 32 2>/dev/null || head -c 64 /dev/urandom | od -An -tx1 | tr -d ' \n'
}

# ── print a short password (for admin) ──
gen_password() {
    openssl rand -base64 18 2>/dev/null | tr -d '/+=' | head -c 16
}

# ── boot animation ──
boot_screen() {
    banner
    box "SYSTEM CHECK" "$C" 64
    row "Checking root access"
    sleep 0.2
    row "Detecting OS (Debian/Ubuntu)"
    sleep 0.2
    row "Installing dependencies (docker, compose)"
    sleep 0.2
    row "Deploying Remnawave Panel stack"
    sleep 0.2
    progress 30 100 "init"
    sleep 0.3
    box_end "$C" 64
    echo ""
}

# ───────────────────────────────────────────────────────────────────────────
# 3. SYSTEM CHECKS
# ───────────────────────────────────────────────────────────────────────────
require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        err "Run this script as root: sudo bash install_remnawave.sh"
        exit 1
    fi
    ok "Root access confirmed"
}

detect_os() {
    if ! command -v apt-get >/dev/null 2>&1; then
        err "Only Debian/Ubuntu supported (apt required). Detected: $(uname -s)"
        exit 1
    fi
    local os_name
    os_name=$(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME")
    ok "OS: ${os_name:-$(uname -r)}"
}

# ───────────────────────────────────────────────────────────────────────────
# 4. DEPENDENCY INSTALLATION
# ───────────────────────────────────────────────────────────────────────────
install_deps() {
    info "Updating package lists..."
    (apt-get update -y >/dev/null 2>&1) &
    spin $! "apt-get update"

    (apt-get install -y curl wget jq unzip >/dev/null 2>&1) &
    spin $! "Base packages (curl wget jq unzip)"

    if ! command -v docker >/dev/null 2>&1; then
        info "Docker not found — installing..."
        (curl -fsSL https://get.docker.com | bash >/dev/null 2>&1) &
        spin $! "get.docker.com"
    fi
    ok "Docker: $(docker --version 2>/dev/null | _plain)"

    if ! docker compose version >/dev/null 2>&1; then
        info "Docker Compose plugin missing — installing..."
        (apt-get install -y docker-compose-plugin >/dev/null 2>&1) &
        spin $! "docker-compose-plugin"
    fi
    ok "Compose: $(docker compose version 2>/dev/null | _plain)"

    # ensure Docker is active
    systemctl enable docker >/dev/null 2>&1
    systemctl start docker >/dev/null 2>&1
    ok "Docker daemon is active"
}

# ───────────────────────────────────────────────────────────────────────────
# 5. PORT CONFLICT CHECK
# ───────────────────────────────────────────────────────────────────────────
check_ports() {
    local ports=(80 443)
    local conflict=false
    for p in "${ports[@]}"; do
        if ! port_free "$p"; then
            err "Port $p is already in use!"
            ss -tlnp 2>/dev/null | grep ":${p} " | head -3
            conflict=true
        fi
    done
    if [ "$conflict" = true ]; then
        echo ""
        err "Free the required ports before proceeding."
        return 1
    fi
    ok "Ports 80 and 443 are free"
}

# ───────────────────────────────────────────────────────────────────────────
# 6. DOMAIN COLLECTION
# ───────────────────────────────────────────────────────────────────────────
collect_domains() {
    box "DOMAIN CONFIGURATION" "$C" 64
    row "1) Panel domain   (e.g. panel.example.com)"
    row "2) Subscription    (e.g. sub.example.com — optional)"
    row "3) Node domain     (e.g. node.example.com — optional)"
    row "4) Email for SSL"
    box_end "$C" 64
    echo ""

    ask "Panel domain:" PANEL_DOMAIN
    [ -z "$PANEL_DOMAIN" ] && { err "Panel domain is required"; exit 1; }

    ask "Subscription page domain (empty to skip):" SUBDOMAIN
    if [ -z "$SUBDOMAIN" ]; then INSTALL_SUB_PAGE=false; else INSTALL_SUB_PAGE=true; fi

    ask "Node domain (empty to skip):" NODE_DOMAIN

    ask "Email for Let's Encrypt SSL:" EMAIL

    echo ""
    info "Checking DNS resolution..."
    for d in "$PANEL_DOMAIN" "$SUBDOMAIN"; do
        [ -z "$d" ] && continue
        local ip
        ip=$(getent hosts "$d" 2>/dev/null | awk '{print $1}' | head -1)
        if [ -n "$ip" ]; then
            ok "$d → $ip"
        else
            warn "DNS for $d not resolved — create an A record pointing to this server"
        fi
    done
}

# ───────────────────────────────────────────────────────────────────────────
# 7. GENERATE .env
# ───────────────────────────────────────────────────────────────────────────
write_env() {
    mkdir -p "$DIR"
    info "Generating secrets..."
    progress 20 100 "generating secrets"

    local db_pass webhook_secret
    db_pass=$(gen_secret)
    webhook_secret=$(gen_secret)
    ADMIN_PASSWORD=$(gen_password)
    progress 50 100 "writing .env"

    cat > "$DIR/.env" <<ENVEOF
### Remnawave Panel v${SCRIPT_VERSION} ###

### Domains ###
PANEL_DOMAIN=${PANEL_DOMAIN}
FRONT_END_DOMAIN=*
SUB_PUBLIC_DOMAIN=${SUBDOMAIN}
SUBSCRIBE_DOMAIN=${SUBDOMAIN}

### API ###
API_INSTANCES=1
METRICS_PORT=3001
APP_PORT=3000
APP_SECRET=$(gen_secret)

### Database ###
DATABASE_URL=postgresql://postgres:${db_pass}@remnawave-db:5432/postgres

### Valkey (Redis) ###
REDIS_SOCKET=/var/run/valkey/valkey.sock

### PostgreSQL Container ###
POSTGRES_USER=postgres
POSTGRES_PASSWORD=${db_pass}
POSTGRES_DB=postgres

### Prometheus / Metrics ###
METRICS_USER=admin
METRICS_PASS=$(gen_secret)

### Webhook ###
WEBHOOK_SECRET_HEADER=${webhook_secret}

### Telegram (optional) ###
IS_TELEGRAM_NOTIFICATIONS_ENABLED=false
ENVEOF

    progress 80 100 "setting permissions"
    chmod 600 "$DIR/.env"
    progress 100 100 "done"
    ok ".env created at $DIR/.env"
}

# ───────────────────────────────────────────────────────────────────────────
# 8. DOCKER-COMPOSE (panel + db + valkey)
# ───────────────────────────────────────────────────────────────────────────
write_compose() {
    info "Creating docker-compose.yml..."

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
    <<: [*common, *logging]
    env_file: .env
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
# 9. CADDYFILE  (bridge network, no catch-all :443)
# ───────────────────────────────────────────────────────────────────────────
write_caddyfile() {
    mkdir -p "$DIR/caddy"
    info "Creating Caddyfile..."

    local sub_block=""
    if [ "$INSTALL_SUB_PAGE" = "true" ] && [ -n "$SUBDOMAIN" ]; then
        sub_block="
https://${SUBDOMAIN} {
    encode
    reverse_proxy * http://remnawave-subscription-page:3010
}"
    fi

    cat > "$DIR/caddy/Caddyfile" <<CADDYEOF
https://${PANEL_DOMAIN} {
    encode
    reverse_proxy * http://remnawave:3000
}
${sub_block}
CADDYEOF

    ok "Caddyfile created (no catch-all :443 block — avoids cert errors)"
}

# ───────────────────────────────────────────────────────────────────────────
# 10. CADDY DOCKER-COMPOSE (bridge network)
# ───────────────────────────────────────────────────────────────────────────
write_caddy_compose() {
    info "Creating Caddy docker-compose..."
    mkdir -p "$DIR/caddy"

    cat > "$DIR/caddy/docker-compose.yml" <<'CADDYCEOF'
services:
  caddy:
    image: caddy:latest
    container_name: caddy
    hostname: caddy
    restart: always
    ports:
      - "80:80"
      - "443:443"
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
    driver: bridge
    external: true
CADDYCEOF

    ok "Caddy compose created (bridge network)"
}

# ───────────────────────────────────────────────────────────────────────────
# 11. SUBSCRIPTION PAGE (optional)
# ───────────────────────────────────────────────────────────────────────────
write_sub_page() {
    [ "$INSTALL_SUB_PAGE" = "false" ] && { info "Subscription page skipped"; return; }

    info "Preparing subscription page..."
    mkdir -p "$DIR/subscription"

    cat > "$DIR/subscription/.env" <<SUBEOF
APP_PORT=3010
REMNAWAVE_PANEL_URL=http://remnawave:3000
REMNAWAVE_API_TOKEN=PASTE_YOUR_API_TOKEN_HERE
CUSTOM_SUB_PREFIX=
MARZBAN_LEGACY_LINK_ENABLED=false
TRUST_PROXY=1
SUBEOF

    cat > "$DIR/subscription/docker-compose.yml" <<'SUBCEOF'
services:
  remnawave-subscription-page:
    image: remnawave/subscription-page:latest
    container_name: remnawave-subscription-page
    hostname: remnawave-subscription-page
    restart: always
    env_file: .env
    ports:
      - "127.0.0.1:3010:3010"
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

networks:
  remnawave-network:
    driver: bridge
    external: true
SUBCEOF

    ok "Subscription page compose created"
    warn "After first panel boot, create an API token (Settings → API Tokens) and paste it into:"
    warn "  $DIR/subscription/.env → REMNAWAVE_API_TOKEN"
    warn "  Then restart: cd $DIR/subscription && docker compose restart"
}

# ───────────────────────────────────────────────────────────────────────────
# 12. START SERVICES
# ───────────────────────────────────────────────────────────────────────────
start_services() {
    info "Starting panel stack..."
    (cd "$DIR" && docker compose up -d >/dev/null 2>&1) &
    spin $! "docker compose up -d (panel)"

    if [ "$INSTALL_SUB_PAGE" = "true" ]; then
        info "Starting Caddy reverse proxy..."
        (cd "$DIR/caddy" && docker compose up -d >/dev/null 2>&1) &
        spin $! "docker compose up -d (caddy)"

        info "Starting subscription page..."
        (cd "$DIR/subscription" && docker compose up -d >/dev/null 2>&1) &
        spin $! "docker compose up -d (subscription)"
    else
        info "Starting Caddy reverse proxy..."
        (cd "$DIR/caddy" && docker compose up -d >/dev/null 2>&1) &
        spin $! "docker compose up -d (caddy)"
    fi

    info "Waiting for panel healthcheck..."
    local tries=0
    while [ "$tries" -lt 60 ]; do
        if curl -sf http://127.0.0.1:3001/health >/dev/null 2>&1; then
            ok "Panel is healthy"
            return 0
        fi
        progress "$tries" 60 "waiting..."
        tries=$((tries + 1)); sleep 2
    done
    warn "Panel healthcheck timed out — check: docker logs remnawave"
}

# ───────────────────────────────────────────────────────────────────────────
# 13. AUTO-CREATE ADMIN (after first boot)
# ───────────────────────────────────────────────────────────────────────────
auto_create_admin() {
    info "Creating default admin account..."
    local output
    output=$(docker exec remnawave node /app/dist/cli/cli.js admin create \
        --login admin --password "$ADMIN_PASSWORD" 2>&1) || true

    if echo "$output" | grep -qi "already exists\|created\|success"; then
        ok "Admin user 'admin' created"
    else
        warn "Admin auto-create may have failed: $output"
        warn "You can create manually after boot"
    fi
}

# ───────────────────────────────────────────────────────────────────────────
# 14. INSTALLATION SUMMARY
# ───────────────────────────────────────────────────────────────────────────
summary() {
    clear
    banner
    box "INSTALLATION COMPLETE" "$G" 64
    echo ""
    kv "Panel URL" "https://${PANEL_DOMAIN}"
    [ "$INSTALL_SUB_PAGE" = "true" ] && kv "Subscription" "https://${SUBDOMAIN}"
    [ -n "$NODE_DOMAIN" ] && kv "Node Domain" "${NODE_DOMAIN}"
    kv "Admin Login" "admin"
    kv "Admin Password" "${ADMIN_PASSWORD}"
    kv "Install Dir" "${DIR}"
    kv "Stack File" "${DIR}/docker-compose.yml"
    kv "Caddy File" "${DIR}/caddy/Caddyfile"
    kv "Env File" "${DIR}/.env"
    echo ""
    box_end "$G" 64
    echo ""

    if [ "${#_warnings[@]}" -gt 0 ]; then
        echo -e "  ${Y}┌─ Warnings ─────────────────────────────────────┐${C_RESET}"
        for w in "${_warnings[@]}"; do
            printf "  ${Y}│${C_RESET}  ${W}%.50s${C_RESET}\n" "$w"
        done
        echo -e "  ${Y}└───────────────────────────────────────────────┘${C_RESET}"
        echo ""
    fi

    echo -e "  ${G}✔${C_RESET} Panel installed successfully! Open in browser."
    echo -e "  ${D}  Save the admin password above — it won't be shown again.${C_RESET}"
    echo ""
}

# ───────────────────────────────────────────────────────────────────────────
# 15. MAIN INSTALL FLOW
# ───────────────────────────────────────────────────────────────────────────
main_install() {
    boot_screen
    require_root
    detect_os
    install_deps
    check_ports || { err "Cannot proceed with port conflicts"; exit 1; }
    collect_domains
    write_env
    write_compose
    write_caddyfile
    write_caddy_compose
    write_sub_page
    start_services
    auto_create_admin
    summary
}

# ═══════════════════════════════════════════════════════════════════════════
#  MENU OPTIONS
# ═══════════════════════════════════════════════════════════════════════════

# ───────────────────────────────────────────────────────────────────────────
# A. INSTALL NODE
# ───────────────────────────────────────────────────────────────────────────
menu_install_node() {
    clear
    banner
    box "INSTALL REMNANODE" "$B" 64
    echo ""
    row "This installs the Remnawave Node on THIS server"
    row "using network_mode: host for wireguard support"
    echo ""
    box_end "$B" 64
    echo ""

    local node_secret=""
    ask "Enter SECRET_KEY (from panel → Nodes → Add):" node_secret
    [ -z "$node_secret" ] && { err "SECRET_KEY is required"; pause_menu; return; }

    local node_port=2222
    ask "Node port [2222]:" node_port_input
    [ -n "$node_port_input" ] && node_port="$node_port_input"

    info "Installing Docker if needed..."
    if ! command -v docker >/dev/null 2>&1; then
        (curl -fsSL https://get.docker.com | bash >/dev/null 2>&1) &
        spin $! "get.docker.com"
    fi

    mkdir -p /opt/remnanode

    cat > /opt/remnanode/docker-compose.yml <<NODEEOF
services:
  remnanode:
    container_name: remnanode
    hostname: remnanode
    image: remnawave/node:latest
    restart: always
    network_mode: host
    cap_add:
      - NET_ADMIN
    ulimits:
      nofile:
        soft: 1048576
        hard: 1048576
    environment:
      - NODE_PORT=${node_port}
      - SECRET_KEY=${node_secret}
    volumes:
      - /var/log/remnanode:/var/log/remnanode
NODEEOF

    (cd /opt/remnanode && docker compose up -d >/dev/null 2>&1) &
    spin $! "docker compose up -d (remnanode)"

    ok "Remnanode installed and started on port $node_port"
    echo ""
    box "NODE STATUS" "$G" 64
    kv "Image" "remnawave/node:latest"
    kv "Port" "${node_port}"
    kv "Compose" "/opt/remnanode/docker-compose.yml"
    kv "Network" "host (wireguard)"
    kv "Capabilities" "NET_ADMIN"
    box_end "$G" 64
    pause_menu
}

# ───────────────────────────────────────────────────────────────────────────
# B. BACKUP
# ───────────────────────────────────────────────────────────────────────────
menu_backup() {
    clear
    banner
    box "BACKUP PANEL DATA" "$Y" 64
    echo ""
    row "This dumps the PostgreSQL database and copies config files"
    row "into a timestamped tar.gz in ${BACKUP_DIR}/"
    echo ""
    box_end "$Y" 64
    echo ""

    if ! confirm "Proceed with backup?"; then
        info "Backup cancelled"
        pause_menu
        return
    fi

    mkdir -p "$BACKUP_DIR"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local tmpdir
    tmpdir=$(mktemp -d)

    info "Dumping PostgreSQL database..."
    docker exec remnawave-db pg_dumpall -U postgres > "$tmpdir/pgdump.sql" 2>/dev/null
    if [ -s "$tmpdir/pgdump.sql" ]; then
        ok "Database dump: $(wc -c < "$tmpdir/pgdump.sql") bytes"
    else
        warn "Database dump may be empty — check if remnawave-db is running"
    fi

    info "Copying configuration files..."
    cp "$DIR/.env" "$tmpdir/dotenv" 2>/dev/null
    cp "$DIR/docker-compose.yml" "$tmpdir/docker-compose.yml" 2>/dev/null
    cp "$DIR/caddy/Caddyfile" "$tmpdir/Caddyfile" 2>/dev/null
    cp "$DIR/caddy/docker-compose.yml" "$tmpdir/caddy-compose.yml" 2>/dev/null
    [ "$INSTALL_SUB_PAGE" = "true" ] && {
        mkdir -p "$tmpdir/subscription"
        cp "$DIR/subscription/.env" "$tmpdir/subscription/.env" 2>/dev/null
        cp "$DIR/subscription/docker-compose.yml" "$tmpdir/subscription/docker-compose.yml" 2>/dev/null
    }
    ok "Config files copied"

    info "Creating tarball..."
    local backup_file="$BACKUP_DIR/remnawave_backup_${timestamp}.tar.gz"
    tar -czf "$backup_file" -C "$tmpdir" . 2>/dev/null
    rm -rf "$tmpdir"

    if [ -f "$backup_file" ]; then
        local size
        size=$(du -h "$backup_file" | awk '{print $1}')
        echo ""
        box "BACKUP COMPLETE" "$G" 64
        kv "File" "${backup_file}"
        kv "Size" "${size}"
        kv "Time" "${timestamp}"
        box_end "$G" 64
    else
        err "Backup tarball creation failed"
    fi
    pause_menu
}

# ───────────────────────────────────────────────────────────────────────────
# C. STATUS CHECKER
# ───────────────────────────────────────────────────────────────────────────
menu_status() {
    clear
    banner
    box "SYSTEM STATUS" "$C" 64
    echo ""

    # Docker containers
    row "── Docker Containers ──" "$B"
    local ps_output
    ps_output=$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null)
    if [ -n "$ps_output" ]; then
        echo "$ps_output" | while IFS= read -r line; do
            printf "  ${C}│${C_RESET} ${D}%s${C_RESET}\n" "$line"
        done
    else
        row "  No containers running"
    fi
    echo ""

    # Health endpoint
    row "── Health Endpoints ──" "$B"
    if curl -sf http://127.0.0.1:3001/health >/dev/null 2>&1; then
        kv "Panel health" "✔ UP (port 3001)"
    else
        kv "Panel health" "✘ DOWN"
    fi

    if curl -sf http://127.0.0.1:3000 >/dev/null 2>&1; then
        kv "Panel web" "✔ UP (port 3000)"
    else
        kv "Panel web" "✘ DOWN"
    fi

    if curl -sf https://127.0.0.1:443 -k >/dev/null 2>&1; then
        kv "Caddy HTTPS" "✔ UP (port 443)"
    else
        kv "Caddy HTTPS" "!"
    fi

    if [ "$INSTALL_SUB_PAGE" = "true" ]; then
        if curl -sf http://127.0.0.1:3010 >/dev/null 2>&1; then
            kv "Subscription" "✔ UP (port 3010)"
        else
            kv "Subscription" "✘ DOWN"
        fi
    fi
    echo ""

    # Ports
    row "── Listening Ports ──" "$B"
    for p in 80 443 3000 3001 6767 3010; do
        if ss -tlnp 2>/dev/null | grep -q ":${p} "; then
            kv "Port $p" "✔ LISTENING"
        else
            kv "Port $p" "— free"
        fi
    done
    echo ""

    # Disk / Memory
    row "── System Resources ──" "$B"
    local disk_info mem_info
    disk_info=$(df -h / 2>/dev/null | tail -1 | awk '{print $3 "/" $2 " used (" $5 ")"}')
    mem_info=$(free -h 2>/dev/null | awk '/^Mem:/{print $3 "/" $2 " used"}')
    kv "Disk (/)" "${disk_info:-N/A}"
    kv "Memory" "${mem_info:-N/A}"
    kv "Docker" "$(docker system df --format '{{.Type}}: {{.Size}}' 2>/dev/null | tr '\n' ', ' || echo 'N/A')"
    echo ""

    box_end "$C" 64
    pause_menu
}

# ───────────────────────────────────────────────────────────────────────────
# D. UNINSTALL
# ───────────────────────────────────────────────────────────────────────────
menu_uninstall() {
    clear
    banner
    box "UNINSTALL REMNAWAVE" "$R" 64
    echo ""
    row "This will stop and remove ALL containers,"
    row "volumes, and configuration files."
    echo ""
    row "THIS ACTION IS IRREVERSIBLE." "$R"
    echo ""
    box_end "$R" 64
    echo ""

    # Triple confirmation
    echo -en "  ${R}[?]${C_RESET} ${W}Type ${R}DELETE${C_RESET} to confirm uninstall: "
    read -r confirm_input
    if [ "$confirm_input" != "DELETE" ]; then
        info "Uninstall cancelled"
        pause_menu
        return
    fi

    info "Stopping containers..."

    # Stop subscription page
    if [ -d "$DIR/subscription" ]; then
        (cd "$DIR/subscription" && docker compose down -v >/dev/null 2>&1) &
        spin $! "Removing subscription containers"
    fi

    # Stop caddy
    if [ -d "$DIR/caddy" ]; then
        (cd "$DIR/caddy" && docker compose down -v >/dev/null 2>&1) &
        spin $! "Removing Caddy containers"
    fi

    # Stop main panel stack
    if [ -f "$DIR/docker-compose.yml" ]; then
        (cd "$DIR" && docker compose down -v >/dev/null 2>&1) &
        spin $! "Removing panel containers & volumes"
    fi

    # Stop remnanode
    if [ -d /opt/remnanode ]; then
        (cd /opt/remnanode && docker compose down -v >/dev/null 2>&1) &
        spin $! "Removing remnanode containers"
    fi

    info "Removing files..."
    rm -rf "$DIR"
    rm -rf /opt/remnanode
    ok "All files removed from $DIR and /opt/remnanode"

    echo ""
    box "UNINSTALL COMPLETE" "$G" 64
    echo ""
    row "All Remnawave containers and files removed"
    row "Docker itself was not uninstalled"
    echo ""
    box_end "$G" 64
    pause_menu
}

# ───────────────────────────────────────────────────────────────────────────
# 16. MAIN MENU (btop-style)
# ───────────────────────────────────────────────────────────────────────────
show_main_menu() {
    while true; do
        header
        box_line "${W}CHOOSE ACTION${C_RESET}" 60
        echo ""
        echo -e "  ${G}1${C_RESET}.  Install Remnawave Panel"
        echo -e "  ${B}2${C_RESET}.  Install Remnanode"
        echo ""
        echo -e "  ${Y}3${C_RESET}.  Backup Panel Data"
        echo -e "  ${C}4${C_RESET}.  Check System Status"
        echo -e "  ${R}5${C_RESET}.  Uninstall Everything"
        echo -e "  ${D}0${C_RESET}.  Exit"
        echo ""
        ask "Your choice:" choice

        case "$choice" in
            1)
                main_install
                pause_menu
                ;;
            2)
                menu_install_node
                ;;
            3)
                menu_backup
                ;;
            4)
                menu_status
                ;;
            5)
                menu_uninstall
                ;;
            0|"q"|"exit")
                echo -e "  ${Y}[!]${C_RESET} Goodbye"
                exit 0
                ;;
            *)
                warn "Invalid choice: '$choice'"
                sleep 1
                ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════════════════════
# 17. DISPATCHER
# ═══════════════════════════════════════════════════════════════════════════
case "${1:-}" in
    install|-i|--install)
        main_install
        ;;
    menu|-m|--menu)
        show_main_menu
        ;;
    version|-v|--version)
        echo "remnawave-installer v${SCRIPT_VERSION}"
        ;;
    *)
        show_main_menu
        ;;
esac
