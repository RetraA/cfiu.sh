#!/bin/bash
set -u
set -o pipefail

#################################
# CFIU — Cloudflare IP Updater
# Multi-record / multi-zone
# Auto dependency install
# Built-in uninstall (-u) with optional dependencies removal
#################################

CONFIG_DIR="/etc/cfiu"
CONFIG_FILE="$CONFIG_DIR/config.json"
INIT_MARKER="$CONFIG_DIR/.initialized"
LOG_DIR="/var/log/cfiu"
SCRIPT_PATH="$(realpath "$0")"

# Colors
BLUE="\033[1;34m"
GREEN="\033[1;32m"
RED="\033[1;31m"
WHITE="\033[0;37m"
RESET="\033[0m"

msg_blue()  { echo -e "${BLUE}[CFIU]${RESET} $1"; }
msg_green() { echo -e "${GREEN}[CFIU]${RESET} $1"; }
msg_red()   { echo -e "${RED}[CFIU]${RESET} $1"; }

#################################
# Uninstall
#################################
if [[ "${1:-}" == "-u" || "${1:-}" == "--uninstall" ]]; then
    REMOVE_DEPS=false
    [[ "${2:-}" == "--deps" ]] && REMOVE_DEPS=true

    echo "⚠ This will remove CFIU script, configs, and logs."
    [[ "$REMOVE_DEPS" == true ]] && echo "⚠ It will also remove curl and jq if confirmed."
    read -p "Are you sure? (y)es / (n)o: " CONFIRM

    CONFIRM="${CONFIRM,,}"  # convert to lowercase
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "yes" ]]; then
        echo "Aborted."
        exit 0
    fi

    [[ -f "$SCRIPT_PATH" ]] && sudo rm -f "$SCRIPT_PATH" && echo "Removed script: $SCRIPT_PATH"
    [[ -d "$CONFIG_DIR" ]] && sudo rm -rf "$CONFIG_DIR" && echo "Removed config: $CONFIG_DIR"
    [[ -d "$LOG_DIR" ]] && sudo rm -rf "$LOG_DIR" && echo "Removed logs: $LOG_DIR"

    if [[ "$REMOVE_DEPS" == true ]]; then
        echo "Removing dependencies curl and jq..."
        if command -v apt >/dev/null; then
            sudo apt remove -y curl jq
        elif command -v dnf >/dev/null; then
            sudo dnf remove -y curl jq
        elif command -v yum >/dev/null; then
            sudo yum remove -y curl jq
        elif command -v pacman >/dev/null; then
            sudo pacman -Rs --noconfirm curl jq
        else
            echo "Unsupported package manager. Remove curl and jq manually."
        fi
    fi

    echo "✅ CFIU has been completely removed."
    exit 0
fi

#################################
# First-run banner
#################################
if [[ ! -f "$INIT_MARKER" ]]; then
  echo -e "${WHITE}\
█████▄  ▄▄▄▄▄ ▄▄▄▄▄▄ ▄▄▄▄   ▄▄▄    ██      ▄▄▄  ▄▄▄▄   ▄▄▄▄ 
██▄▄██▄ ██▄▄    ██   ██▄█▄ ██▀██   ██     ██▀██ ██▄██ ███▄▄ 
██   ██ ██▄▄▄   ██   ██ ██ ██▀██   ██████ ██▀██ ██▄█▀ ▄▄██▀${RESET}"
  echo
  mkdir -p "$CONFIG_DIR"
  touch "$INIT_MARKER"
fi

#################################
# Run as root if needed
#################################
SUDO=""
[[ $EUID -ne 0 ]] && SUDO="sudo"

#################################
# Install dependencies
#################################
install_deps() {
    local missing=()
    command -v curl >/dev/null || missing+=("curl")
    command -v jq   >/dev/null || missing+=("jq")
    [[ ${#missing[@]} -eq 0 ]] && return

    msg_blue "Installing: ${WHITE}${missing[*]}${RESET}"

    if command -v apt >/dev/null; then
        $SUDO apt update -y
        $SUDO apt install -y "${missing[@]}"
    elif command -v dnf >/dev/null; then
        $SUDO dnf install -y "${missing[@]}"
    elif command -v yum >/dev/null; then
        $SUDO yum install -y "${missing[@]}"
    elif command -v pacman >/dev/null; then
        $SUDO pacman -Sy --noconfirm "${missing[@]}"
    else
        msg_red "Cannot install dependencies automatically. Install curl and jq manually."
        exit 1
    fi
}

install_deps

#################################
# First-run config
#################################
if [[ ! -f "$CONFIG_FILE" ]]; then
    msg_blue "Config not found. Creating default..."

    $SUDO tee "$CONFIG_FILE" >/dev/null <<'EOF'
{
  "API Key": "PASTE YOUR CLOUDFLARE API KEY WITH DNS ZONE PERMISSIONS.",
  "_comment": "IF YOU HAVE MULTIPLE DOMAINS, USE THE EXAMPLES BELOW. FOR SAME ZONE DNS RECORDS USE THE SAME ZONE ID. IF YOU WANT TO CHECK THE A OR AAAA RECORDS OF A DNS, CLASSIFY IT LIKE THE FIRST EXAMPLE.",
  "records": [
    {
      "Zone Id": "ZONE_ID",
      "domain": "home.example.com",
      "types": ["A","AAAA"],
      "ttl": 120,
      "proxied": false
    },
    {
      "Zone Id": "ZONE_ID",
      "domain": "vpn.example.net",
      "types": ["A"],
      "ttl": 120,
      "proxied": false
    },
    {
      "Zone Id": "ZONE_ID",
      "domain": "nas.example.net",
      "types": ["A"],
      "ttl": 300,
      "proxied": false
    },
    {
      "Zone Id": "ZONE_ID",
      "domain": "media.example.net",
      "types": ["A","AAAA"],
      "ttl": 120,
      "proxied": true
    }
  ]
}
EOF

    $SUDO chmod 600 "$CONFIG_FILE"
    msg_green "Created ${WHITE}$CONFIG_FILE${RESET}"
    msg_blue "Edit it and re-run the script"
    exit 0
fi

#################################
# Load config
#################################
API_KEY=$(jq -r '.["API Key"]' "$CONFIG_FILE")

#################################
# CONFIG VALIDATION
#################################
if [[ -z "$API_KEY" || "$API_KEY" == "PASTE YOUR CLOUDFLARE API KEY WITH DNS ZONE PERMISSIONS." ]]; then
    msg_red "❌ API Key is not set! Please edit $CONFIG_FILE and provide a valid API Key."
    exit 1
fi

# Validate all DNS records
INVALID_RECORDS=$(jq -c '.records[]' "$CONFIG_FILE" | while read -r REC; do
    ZONE_ID=$(echo "$REC" | jq -r '.["Zone Id"]')
    DOMAIN=$(echo "$REC" | jq -r '.domain')
    if [[ -z "$ZONE_ID" || "$ZONE_ID" == "ZONE_ID" ]]; then
        echo "Zone Id missing for domain $DOMAIN"
    fi
    if [[ -z "$DOMAIN" || "$DOMAIN" == "example.com" ]]; then
        echo "Domain not set for Zone Id $ZONE_ID"
    fi
done)

if [[ -n "$INVALID_RECORDS" ]]; then
    msg_red "❌ Invalid DNS records found in config:"
    echo "$INVALID_RECORDS"
    exit 1
fi

#################################
# Get public IPs
#################################
IPV4_SERVICE="https://checkip.amazonaws.com"
IPV6_SERVICE="https://api64.ipify.org"

get_ipv4() { curl -fs "$IPV4_SERVICE" 2>/dev/null || true; }
get_ipv6() { curl -fs "$IPV6_SERVICE" 2>/dev/null || true; }

PUBLIC_IPV4="$(get_ipv4 | tr -d '\n')"
PUBLIC_IPV6="$(get_ipv6 | tr -d '\n')"

msg_blue "IPv4: ${WHITE}${PUBLIC_IPV4:-none}${RESET}"
msg_blue "IPv6: ${WHITE}${PUBLIC_IPV6:-none}${RESET}"
echo

# Skip update if no IPs
if [[ -z "$PUBLIC_IPV4" && -z "$PUBLIC_IPV6" ]]; then
    msg_red "❌ No public IPv4 or IPv6 detected. Skipping update."
    exit 0
fi

if [[ -z "$PUBLIC_IPV4" ]]; then
    msg_red "❌ No public IPv4 detected. Will not update A records."
fi

if [[ -z "$PUBLIC_IPV6" ]]; then
    msg_red "❌ No public IPv6 detected. Will not update AAAA records."
fi

#################################
# Cloudflare API helper
#################################
cf_api() {
    curl -s -H "Authorization: Bearer $API_KEY" -H "Content-Type: application/json" "$@"
}

#################################
# Update all DNS records
#################################
jq -c '.records[]' "$CONFIG_FILE" | while read -r REC; do
    ZONE_ID=$(echo "$REC" | jq -r '.["Zone Id"]')
    DOMAIN=$(echo "$REC" | jq -r '.domain')
    TTL=$(echo "$REC" | jq -r '.ttl // 120')
    PROXIED=$(echo "$REC" | jq -r '.proxied // false')

    msg_blue "Processing ${WHITE}$DOMAIN${RESET}"

    for TYPE in $(echo "$REC" | jq -r '.types[]'); do
        [[ "$TYPE" == "A" ]] && NEW_IP="$PUBLIC_IPV4" || NEW_IP="$PUBLIC_IPV6"
        [[ -z "$NEW_IP" ]] && continue

        RESPONSE=$(cf_api "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=$TYPE&name=$DOMAIN")
        RECORD_ID=$(echo "$RESPONSE" | jq -r '.result[0].id')
        CURRENT_IP=$(echo "$RESPONSE" | jq -r '.result[0].content')

        if [[ "$RECORD_ID" == "null" || -z "$RECORD_ID" ]]; then
            msg_red "  $TYPE record not found for $DOMAIN"
            continue
        fi

        if [[ "$CURRENT_IP" == "$NEW_IP" ]]; then
            msg_green "  IP unchanged"
            continue
        fi

        msg_blue "  Updating $TYPE ${WHITE}$CURRENT_IP → $NEW_IP${RESET}"

        if cf_api -X PUT \
            "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
            --data "{
                \"type\":\"$TYPE\",
                \"name\":\"$DOMAIN\",
                \"content\":\"$NEW_IP\",
                \"ttl\":$TTL,
                \"proxied\":$PROXIED
            }" | jq -e '.success' >/dev/null; then
            msg_green "  $TYPE IP updated"
        else
            msg_red "  $TYPE IP update failed"
        fi
    done
    echo
done

msg_green "CFIU update complete"
