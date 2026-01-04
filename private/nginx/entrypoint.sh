#!/bin/bash

set -e

if [ -z "$SSL_DOMAIN" ]; then
    log_error "SSL_DOMAIN environment variable is not set."
    exit 1
fi

# ==============================================================================
# Configuration
# ==============================================================================
readonly SSL_DIR="/etc/nginx/ssl"
readonly WEBROOT="/var/www/certbot"
readonly CERTBOT_BASE="/etc/letsencrypt/live"
readonly CERTBOT_DIR="$CERTBOT_BASE/$SSL_DOMAIN"

# ==============================================================================
# Logging Helpers
# ==============================================================================
log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

# ==============================================================================
# Environment Validation & Domain Logic
# ==============================================================================
build_domain_list() {
    local domains="$SSL_DOMAIN"

    if [ -n "$SSL_SUBDOMAINS" ]; then
        local subs=$(echo "$SSL_SUBDOMAINS" | tr ',' ' ')
        for sub in $subs; do
            domains="$domains $sub.$SSL_DOMAIN"
        done
    fi
    echo "$domains"
}

# ==============================================================================
# Infrastructure Setup
# ==============================================================================
ensure_directories() {
    mkdir -p "$SSL_DIR" "$WEBROOT"
}

# ==============================================================================
# Certificate Management
# ==============================================================================
is_cert_available() {
    [ -d "$CERTBOT_DIR" ] && \
    [ -f "$CERTBOT_DIR/fullchain.pem" ] && \
    [ -f "$CERTBOT_DIR/privkey.pem" ]
}

link_certificate() {
    local crt="$1"
    local key="$2"

    ln -sf "$crt" "$SSL_DIR/current.crt"
    ln -sf "$key" "$SSL_DIR/current.key"
}

create_dummy_certificate() {
    if [ ! -f "$SSL_DIR/current.crt" ]; then
        log_info "Generating dummy self-signed certificate..."
        openssl req -x509 -nodes -newkey rsa:4096 -days 1 \
            -keyout "$SSL_DIR/dummy.key" \
            -out "$SSL_DIR/dummy.crt" \
            -subj "/CN=localhost" \
            2>/dev/null
        
        link_certificate "$SSL_DIR/dummy.crt" "$SSL_DIR/dummy.key"
    fi
}

request_lets_encrypt_cert() {
    local domain_list=$(build_domain_list)
    log_info "Requesting Let's Encrypt certificate for: $domain_list"
    
    # Construct argument array for safer handling
    local certbot_args=(
        "certonly"
        "--webroot"
        "-w" "$WEBROOT"
        "--email" "$SSL_EMAIL"
        "--rsa-key-size" "4096"
        "--agree-tos"
        "--non-interactive"
    )

    for domain in $domain_list; do
        certbot_args+=("-d" "$domain")
    done

    if certbot "${certbot_args[@]}"; then
        return 0
    else
        log_error "Certbot request failed."
        return 1
    fi
}

start_renewal_loop() {
    log_info "Starting renewal loop..."
    (
        while true; do
            sleep 12h
            certbot renew \
                --webroot -w "$WEBROOT" \
                --quiet \
                --deploy-hook "nginx -s reload"
        done
    ) &
}

# ==============================================================================
# Nginx Control
# ==============================================================================
start_nginx() {
    log_info "Starting Nginx..."
    nginx -g "daemon off;" &
    NGINX_PID=$!
}

reload_nginx() {
    log_info "Reloading Nginx configuration..."
    nginx -s reload
}

# ==============================================================================
# Main Orchestrator
# ==============================================================================
main() {
    ensure_directories
    create_dummy_certificate
    
    start_nginx
    sleep 5

    if is_cert_available; then
        log_info "Found existing Let's Encrypt certificate for $SSL_DOMAIN"
        link_certificate "$CERTBOT_DIR/fullchain.pem" "$CERTBOT_DIR/privkey.pem"
    else
        if request_lets_encrypt_cert; then
            log_info "Switching to real certificate..."
            link_certificate "$CERTBOT_DIR/fullchain.pem" "$CERTBOT_DIR/privkey.pem"
            reload_nginx
        else
            log_error "Failed to obtain real certificate. Continuing with dummy certificate."
        fi
    fi
    
    start_renewal_loop
    wait "$NGINX_PID"
}

main
