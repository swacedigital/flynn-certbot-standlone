#!/usr/bin/env bash

echo "Type your email: (eg: john@example.com)"
read LETS_ENCRYPT_EMAIL

echo "Type the domain name (eg: example.your-domain.com)"
read DOMAIN

echo "Type Flynn app name associated with the domain (eg: basic-app,basic-app-2 etc)"
read APP_NAMES

echo "Type Flynn Cluster name (eg: my-cluster)"
read FLYNN_CLUSTER_HOST

echo "AWS Acess Key ID"
read AWS_ACCESS_KEY_ID

echo "AWS Secret Access key"
read AWS_SECRET_ACCESS_KEY

flynn -c "$FLYNN_CLUSTER_HOST" create "certbot"

FLYNN_CONTROLLER_KEY=$(flynn -c "$FLYNN_CLUSTER_HOST" -a controller env get AUTH_KEY)

FLYNN_TLS_PIN=$(openssl s_client -connect "controller.$FLYNN_CLUSTER_HOST:443" \
  -servername "controller.$FLYNN_CLUSTER_HOST" 2>/dev/null </dev/null \
  | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' \
  | openssl x509 -inform PEM -outform DER \
  | openssl dgst -binary -sha256 \
  | openssl base64)

flynn env set LETS_ENCRYPT_EMAIL="$LETS_ENCRYPT_EMAIL" DOMAIN="$DOMAIN" APP_NAMES="$APP_NAMES" \
    FLYNN_CLUSTER_HOST="$FLYNN_CLUSTER_HOST" FLYNN_CONTROLLER_KEY="$FLYNN_CONTROLLER_KEY" FLYNN_TLS_PIN="$FLYNN_TLS_PIN" \
    AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"

echo "Deploying certbot.."
git push flynn master

flynn scale web=1
