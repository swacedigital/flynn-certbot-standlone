#!/usr/bin/env bash
FLYNN_CMD="/app/flynn"
CERTBOT_WORK_DIR="/app"
CERTBOT_CONFIG_DIR="/app/config"

echo $APP_NAMES
echo $DOMAIN
echo $LETS_ENCRYPT_EMAIL
echo $FLYNN_CLUSTER_HOST
echo $FLYNN_CONTROLLER_KEY
echo $FLYNN_TLS_PIN


if [ -z "$APP_NAMES" ]; then
    echo "APP_NAMES must be set"
    exit 1
fi

if [ -z "$DOMAIN" ]; then
    echo "DOMAIN must be set"
    exit 1
fi

if [ -z "$LETS_ENCRYPT_EMAIL" ]; then
    echo "LETS_ENCRYPT_EMAIL must be set"
    exit 1
fi

if [ -z "$FLYNN_CLUSTER_HOST" ]; then
    echo "FLYNN_CLUSTER_HOST must be set"
    exit 1
fi

if [ -z "$FLYNN_CONTROLLER_KEY" ]; then
    echo "FLYNN_CONTROLLER_KEY must be set"
    exit 1
fi

if [ -z "$FLYNN_TLS_PIN" ]; then
    echo "FLYNN_TLS_PIN must be set"
    exit 1
fi

# Install flynn-cli
echo "Installing Flynn CLI..."
L="$FLYNN_CMD" && curl -sSL -A "`uname -sp`" https://dl.flynn.io/cli | zcat >$L && chmod +x $L

# Add cluster
echo "Adding cluster $FLYNN_CLUSTER_HOST..."
"$FLYNN_CMD" cluster add -p "$FLYNN_TLS_PIN" "$FLYNN_CLUSTER_HOST" "$FLYNN_CLUSTER_HOST" "$FLYNN_CONTROLLER_KEY"

echo "Setup acme-challange path route"
"$FLYNN_CMD" -c "$FLYNN_CLUSTER_HOST" -a "certbot" route add http "$DOMAIN/.well-known/acme-challenge/"
echo "done"

echo "Generating certificate..."
certbot certonly \
  --standalone \
  --work-dir "$CERTBOT_WORK_DIR" \
  --config-dir "$CERTBOT_CONFIG_DIR" \
  --logs-dir "$CERTBOT_WORK_DIR/logs" \
  --agree-tos \
  --no-eff-email \
  --email $LETS_ENCRYPT_EMAIL \
  --dns-route53
  --dns-route53-propagation-seconds 30 \
  -d "$DOMAIN" \

DOMAIN="${DOMAIN}"
IFS=',' # space is set as delimiter
read -ra NAMES <<< "$APP_NAMES"
while true
    for NAME in "${NAMES[@]}"; do
        APP_NAME="${NAME}"
        # Extract route id
        echo "Extracting route id.."
        ROUTE_ID=$("$FLYNN_CMD" -c "$FLYNN_CLUSTER_HOST" -a "$APP_NAME" route | grep "$DOMAIN" | awk '{print $3}')

        if [[ -z "$ROUTE_ID" ]]; then
            echo "Cannot determine route id: $ROUTE_ID"
            exit 1
        fi

        echo "Updating certificates via Flynn routes... '$DOMAIN' for app '$APP_NAME'..."
        "$FLYNN_CMD" -c "$FLYNN_CLUSTER_HOST" -a "$APP_NAME" route update "$ROUTE_ID" \
            --tls-cert "$CERTBOT_CONFIG_DIR/live/$DOMAIN/fullchain.pem" \
            --tls-key "$CERTBOT_CONFIG_DIR/live/$DOMAIN/privkey.pem"
        echo "done"
    done
    sleep 7d
done
