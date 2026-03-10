#!/bin/sh

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_link() {
    echo -e "${CYAN}$1${NC}"
}

# Check for required variables
if [ -z "$UUID" ]; then
    log_warn "UUID not provided, generating a random one..."
    UUID=$(cat /proc/sys/kernel/random/uuid)
    log_info "Generated UUID: $UUID"
fi

XHTTP_PATH="/$UUID"
XHTTP_PATH_ENCODED="%2F${UUID}"
PORT=8080

log_info "---------------------------------------------------"
log_info "Starting VLESS-xHTTP-ARGO Node (Xray-core)"
log_info "UUID: $UUID"
log_info "XHTTP Path: $XHTTP_PATH"

if [ -n "$ECH_CONFIG" ]; then
    if [ "$ECH_CONFIG" = "true" ]; then
        log_info "ECH: Enabled (Default Config)"
    elif [ "$ECH_CONFIG" != "false" ]; then
        log_info "ECH: Enabled (Custom Config)"
    else
        log_info "ECH: Disabled (Explicitly set to false)"
    fi
else
    log_info "ECH: Disabled"
fi

# Quick Tunnel Mode (TryCloudflare)
if [ -z "$ARGO_TOKEN" ]; then
    log_warn "ARGO_TOKEN not provided. Using Quick Tunnel (trycloudflare.com)..."
    log_warn "Note: Quick Tunnels are temporary and unstable. Not recommended for production."
    USE_QUICK_TUNNEL=true
else
    USE_QUICK_TUNNEL=false
    if [ -n "$PUBLIC_HOSTNAME" ]; then
        log_info "PUBLIC_HOSTNAME: $PUBLIC_HOSTNAME"
    fi
fi
log_info "---------------------------------------------------"

# Generate Xray configuration
cat > config.json <<EOF
{
  "log": {
    "loglevel": "info"
  },
  "inbounds": [
    {
      "port": $PORT,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "level": 0
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "xhttp",
        "security": "none",
        "xhttpSettings": {
          "path": "$XHTTP_PATH",
          "mode": "auto"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF

log_info "Xray configuration generated."

# Start Xray in background
log_info "Starting Xray..."
xray run -c config.json &
XRAY_PID=$!

# Wait for Xray to initialize
sleep 2

if ! kill -0 $XRAY_PID > /dev/null 2>&1; then
    log_error "Xray failed to start."
    exit 1
fi

# Prepare Cloudflared Args
CLOUDFLARED_ARGS="--no-autoupdate"
if [ "$EDGE_IP_VER" = "6" ]; then
    CLOUDFLARED_ARGS="$CLOUDFLARED_ARGS --edge-ip-version 6"
    log_info "Cloudflared: Using IPv6 for Edge Connection"
fi

# Start cloudflared
if [ "$USE_QUICK_TUNNEL" = "true" ]; then
    log_info "Starting cloudflared (Quick Tunnel)..."
    # Start cloudflared and capture output to find the trycloudflare URL
    cloudflared tunnel $CLOUDFLARED_ARGS --url http://localhost:$PORT > /tmp/cloudflared.log 2>&1 &
    CLOUDFLARED_PID=$!
    
    # Wait for the URL to appear in the log
    log_info "Waiting for Quick Tunnel URL..."
    count=0
    while [ $count -lt 30 ]; do
        if grep -q "https://.*\.trycloudflare\.com" /tmp/cloudflared.log; then
            QUICK_URL=$(grep -o 'https://[-a-z0-9]*\.trycloudflare\.com' /tmp/cloudflared.log | head -n 1)
            if [ -n "$QUICK_URL" ]; then
                PUBLIC_HOSTNAME=$(echo "$QUICK_URL" | sed 's/https:\/\///')
                log_info "Quick Tunnel established: $PUBLIC_HOSTNAME"
                break
            fi
        fi
        sleep 1
        count=$((count+1))
    done
    
    if [ -z "$PUBLIC_HOSTNAME" ]; then
        log_error "Failed to obtain Quick Tunnel URL."
        cat /tmp/cloudflared.log
        kill $XRAY_PID $CLOUDFLARED_PID
        exit 1
    fi
else
    log_info "Starting cloudflared tunnel..."
    cloudflared tunnel $CLOUDFLARED_ARGS run --token "$ARGO_TOKEN" &
    CLOUDFLARED_PID=$!
fi

# Generate and Output Links
if [ -n "$PUBLIC_HOSTNAME" ]; then
    # Prepare ECH argument
    ECH_STR=""
    if [ -n "$ECH_CONFIG" ]; then
        if [ "$ECH_CONFIG" = "true" ]; then
            ECH_STR="&ech=cloudflare-ech.com%2Bhttps%3A%2F%2Fvercel.doh.xie.today%2Fapi%2Fdoh%2Fgoogle"
        elif [ "$ECH_CONFIG" != "false" ]; then
            # URL Encode the custom ECH config using awk
            ECH_ENCODED=$(echo -n "$ECH_CONFIG" | awk 'BEGIN {
                for (i = 0; i <= 255; i++) ord[sprintf("%c", i)] = i
            }
            {
                len = length($0)
                for (i = 1; i <= len; i++) {
                    c = substr($0, i, 1)
                    if (c ~ /[a-zA-Z0-9.~_-]/) {
                        printf "%s", c
                    } else {
                        printf "%%%02X", ord[c]
                    }
                }
            }')
            ECH_STR="&ech=${ECH_ENCODED}"
        fi
    fi

    echo ""
    log_info "---------------------------------------------------"
    log_info "VLESS Share Links (Import to v2rayN / sing-box / Clash)"
    log_info "---------------------------------------------------"

    # Define best domains
    DOMAINS="cf.254301.xyz isp.254301.xyz run.254301.xyz adventure-x.org www.hltv.org"
    
    ALL_LINKS=""

    # Output Origin Node (Server is the Argo hostname)
    LINK="vless://${UUID}@${PUBLIC_HOSTNAME}:443?encryption=none&security=tls&sni=${PUBLIC_HOSTNAME}&fp=chrome&type=xhttp&mode=auto&host=${PUBLIC_HOSTNAME}&path=${XHTTP_PATH_ENCODED}${ECH_STR}&alpn=h3%2Ch2%2Chttp%2F1.1#Argo-Origin"
    echo -e "${YELLOW}Server: ${PUBLIC_HOSTNAME} (Origin)${NC}"
    log_link "$LINK"
    echo ""
    ALL_LINKS="${ALL_LINKS}${LINK}\n"

    for DOMAIN in $DOMAINS; do
        LINK="vless://${UUID}@${DOMAIN}:443?encryption=none&security=tls&sni=${PUBLIC_HOSTNAME}&fp=chrome&type=xhttp&mode=auto&host=${PUBLIC_HOSTNAME}&path=${XHTTP_PATH_ENCODED}${ECH_STR}&alpn=h3%2Ch2%2Chttp%2F1.1#${DOMAIN}-Argo"
        
        echo -e "${YELLOW}Server: ${DOMAIN}${NC}"
        log_link "$LINK"
        echo ""
        
        ALL_LINKS="${ALL_LINKS}${LINK}\n"
    done
    
    # Base64 Encode
    if [ -n "$ALL_LINKS" ]; then
        BASE64_LINKS=$(echo -e "$ALL_LINKS" | base64 | tr -d '\n')
        log_info "---------------------------------------------------"
        log_info "Base64 Subscription Link (Copy content below)"
        log_info "---------------------------------------------------"
        log_link "$BASE64_LINKS"
    fi
    log_info "---------------------------------------------------"
else
    log_warn "PUBLIC_HOSTNAME not set. Skipping link generation."
    log_warn "Please set PUBLIC_HOSTNAME to your Cloudflare Tunnel domain (e.g. vless.example.com) to see share links."
fi

# Trap signals to kill both processes
trap "kill $XRAY_PID $CLOUDFLARED_PID; exit" SIGINT SIGTERM

# Wait for any process to exit
wait -n $XRAY_PID $CLOUDFLARED_PID

# Exit with the status of the process that exited first
exit $?
