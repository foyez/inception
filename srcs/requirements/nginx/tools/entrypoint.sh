#!/bin/sh

set -e

# ── Create SSL directory ─────────────────────────────────────────────────────
mkdir -p /etc/nginx/ssl

# ── Generate a self-signed TLS certificate ────────────────────────────────────
#
# -x509      → output a self-signed certificate (not a CSR)
# -nodes     → no passphrase on the private key (nginx can't enter one at startup)
# -days 365  → valid for 1 year
# -newkey rsa:2048 → generate a new 2048-bit RSA key pair
# -keyout    → where to write the private key
# -out       → where to write the certificate
# -subj      → certificate subject (CN = Common Name = domain name)
openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/kaahmed.key \
  -out /etc/nginx/ssl/kaahmed.crt \
  -subj "/C=DE/ST=BW/L=Heilbronn/O=42/CN=kaahmed.42.fr"

# Wait for PHP-FPM in wordpress container to accept TCP connections.
# MAX_TRIES=60
# TRY=0
# until nc -z wordpress 9000; do
#   TRY=$((TRY + 1))
#   if [ "$TRY" -ge "$MAX_TRIES" ]; then
#     echo "wordpress:9000 is not reachable"
#     exit 1
#   fi
#   sleep 2
# done

nginx -t

# ── Start NGINX in foreground ─────────────────────────────────────────────────
# -g 'daemon off;' → prevents NGINX from daemonizing itself
# Without this, nginx would fork to the background and the container would exit
exec nginx -g "daemon off;"