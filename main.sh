#!/usr/bin/env bash
FLYNN_CMD="/app/flynn"
CERTBOT_WORK_DIR="/app"
CERTBOT_CONFIG_DIR="/app/config"

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

echo "Generating certificate..."
certbot certonly \
  --non-interactive \
  --work-dir "$CERTBOT_WORK_DIR" \
  --config-dir "$CERTBOT_CONFIG_DIR" \
  --logs-dir "$CERTBOT_WORK_DIR/logs" \
  --agree-tos \
  --email $LETS_ENCRYPT_EMAIL \
  --dns-route53 \
  --dns-route53-propagation-seconds 30 \
  -d "$DOMAIN" \
  -d "*.$DOMAIN"

if [ ! -f "$CERTBOT_CONFIG_DIR/live/$DOMAIN/fullchain.pem" ]; then
    echo "Missing certificate file fullchain.pem"
    exit 1
fi
if [ ! -f "$CERTBOT_CONFIG_DIR/live/$DOMAIN/privkey.pem" ]; then
    echo "Missing private key file privkey.pem"
    exit 1
fi


DOMAIN="${DOMAIN}"
IFS_PREV=$IFS
IFS=',' # , is set as delimiter
read -ra NAMES <<< "$APP_NAMES"
IFS=$IFS_PREV
while true; do
    for APP_NAME in "${NAMES[@]}"; do
        echo "Extracting route id.."
        ROUTES=$("$FLYNN_CMD" -c "$FLYNN_CLUSTER_HOST" -a "$APP_NAME" route | awk '{print $3}')
        for ROUTE_ID in $ROUTES; do
            if [[ $ROUTE_ID == "ID" ]]; then continue; fi
            echo "Updating certificates via Flynn routes for app '$APP_NAME' and route: '$ROUTE_ID'"
            "$FLYNN_CMD" -c "$FLYNN_CLUSTER_HOST" -a "$APP_NAME" route update "$ROUTE_ID" \
            --tls-cert "$CERTBOT_CONFIG_DIR/live/$DOMAIN/fullchain.pem" \
            --tls-key "$CERTBOT_CONFIG_DIR/live/$DOMAIN/privkey.pem"
        done


        echo "Done updating routes for $APP_NAME"
    done
    sleep 7d
done
