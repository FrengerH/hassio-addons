#!/usr/bin/env bashio

EMAIL=$(bashio::config 'email')
DOMAINS=$(bashio::config 'domains')
KEYFILE=$(bashio::config 'keyfile')
CERTFILE=$(bashio::config 'certfile')
CHALLENGE=$(bashio::config 'challenge')
DNS_PROVIDER=$(bashio::config 'dns.provider')

if [[ "$CHALLENGE" == "dns" ]]; then
  bashio::log.info "Selected DNS Provider: $(bashio::config 'dns.provider')"
else
  bashio::log.info "Selected http verification"
fi

CERT_DIR=/data/letsencrypt
WORK_DIR=/data/workdir

mkdir -p "$WORK_DIR"
mkdir -p "$CERT_DIR"
mkdir -p "/ssl"
chmod +x /run.sh
touch /data/dnsapikey
PROVIDER_ARGUMENTS=()

echo -e "dns_cloudflare_email = $(bashio::config 'dns.cloudflare_email')\n" \
  "dns_cloudflare_api_key = $(bashio::config 'dns.cloudflare_api_key')\n" \
  "dns_cloudxns_api_key = $(bashio::config 'dns.cloudxns_api_key')\n" \
  "dns_cloudxns_secret_key = $(bashio::config 'dns.cloudxns_secret_key')\n" \
  "dns_digitalocean_token = $(bashio::config 'dns.digitalocean_token')\n" \
  "dns_dnsimple_token = $(bashio::config 'dns.dnsimple_token')\n" \
  "dns_dnsmadeeasy_api_key = $(bashio::config 'dns.dnsmadeeasy_api_key')\n" \
  "dns_dnsmadeeasy_secret_key = $(bashio::config 'dns.dnsmadeeasy_secret_key')\n" \
  "dns_gehirn_api_token = $(bashio::config 'dns.gehirn_api_token')\n" \
  "dns_gehirn_api_secret = $(bashio::config 'dns.gehirn_api_secret')\n" \
  "dns_linode_key = $(bashio::config 'dns.linode_key')\n" \
  "dns_linode_version = $(bashio::config 'dns.linode_version')\n" \
  "dns_luadns_email = $(bashio::config 'dns.luadns_email')\n" \
  "dns_luadns_token = $(bashio::config 'dns.luadns_token')\n" \
  "certbot_dns_netcup:dns_netcup_customer_id = $(bashio::config 'dns.netcup_customer_id')\n" \
  "certbot_dns_netcup:dns_netcup_api_key = $(bashio::config 'dns.netcup_api_key')\n" \
  "certbot_dns_netcup:dns_netcup_api_password = $(bashio::config 'dns.netcup_api_password')\n" \
  "dns_nsone_api_key = $(bashio::config 'dns.nsone_api_key')\n" \
  "dns_ovh_endpoint = $(bashio::config 'dns.ovh_endpoint')\n" \
  "dns_ovh_application_key = $(bashio::config 'dns.ovh_application_key')\n" \
  "dns_ovh_application_secret = $(bashio::config 'dns.ovh_application_secret')\n" \
  "dns_ovh_consumer_key = $(bashio::config 'dns.ovh_consumer_key')\n" \
  "dns_rfc2136_server = $(bashio::config 'dns.rfc2136_server')\n" \
  "dns_rfc2136_port = $(bashio::config 'dns.rfc2136_port')\n" \
  "dns_rfc2136_name = $(bashio::config 'dns.rfc2136_name')\n" \
  "dns_rfc2136_secret = $(bashio::config 'dns.rfc2136_secret')\n" \
  "dns_rfc2136_algorithm = $(bashio::config 'dns.rfc2136_algorithm')\n" \
  "aws_access_key_id = $(bashio::config 'dns.aws_access_key_id')\n" \
  "aws_secret_access_key = $(bashio::config 'dns.aws_secret_access_key')\n" \
  "dns_sakuracloud_api_token = $(bashio::config 'dns.sakuracloud_api_token')\n" \
  "dns_sakuracloud_api_secret = $(bashio::config 'dns.sakuracloud_api_secret')" > /data/dnsapikey
chmod 600 /data/dnsapikey

# AWS
if bashio::config.exists 'dns.aws_access_key_id' && bashio::config.exists 'dns.aws_secret_access_key'; then
    AWS_ACCESS_KEY_ID="$(bashio::config 'dns.aws_access_key_id')"
    AWS_SECRET_ACCESS_KEY="$(bashio::config 'dns.aws_secret_access_key')"

    export AWS_ACCESS_KEY_ID
    export AWS_SECRET_ACCESS_KEY
    PROVIDER_ARGUMENTS+=("--${DNS_PROVIDER}")
#Google
elif bashio::config.exists 'dns.google_creds'; then
    GOOGLE_CREDS="$(bashio::config 'dns.google_creds')"

    export GOOGLE_CREDS
    if [ -f "/share/${GOOGLE_CREDS}" ]; then
      cp -f "/share/${GOOGLE_CREDS}" "/data/${GOOGLE_CREDS}"
      chmod 600 "/data/${GOOGLE_CREDS}"
    else
      bashio::log.info "Google Credentials File doesnt exists in folder share."
    fi
    PROVIDER_ARGUMENTS+=("--${DNS_PROVIDER}" "--${DNS_PROVIDER}-credentials" "/data/${GOOGLE_CREDS}")
#Netcup
elif bashio::config.exists 'dns.netcup_customer_id' && bashio::config.exists 'dns.netcup_api_key' && bashio::config.exists 'dns.netcup_api_password'; then
    if bashio::config.exists 'dns.netcup_propagation_seconds'; then
      NETCUP_DNS_PROPAGATION_SECONDS="$(bashio::config 'dns.netcup_propagation_seconds')"
    else
      NETCUP_DNS_PROPAGATION_SECONDS=600
      bashio::log.info "no propagation time found for netcup, using default value"
    fi

    PROVIDER_ARGUMENTS+=("--authenticator" "certbot-dns-netcup:dns-netcup" "--certbot-dns-netcup:dns-netcup-credentials" /data/dnsapikey "--certbot-dns-netcup:dns-netcup-propagation-seconds" "${NETCUP_DNS_PROPAGATION_SECONDS}")

#All others
else
    PROVIDER_ARGUMENTS+=("--${DNS_PROVIDER}" "--${DNS_PROVIDER}-credentials" /data/dnsapikey)
fi

# Generate new certs
if [ ! -d "$CERT_DIR/live" ]; then
    DOMAIN_ARR=()
    for line in $DOMAINS; do
        DOMAIN_ARR+=(-d "$line")
    done

    echo "$DOMAINS" > /data/domains.gen
    if [ "$CHALLENGE" == "dns" ]; then
        certbot certonly --non-interactive --config-dir "$CERT_DIR" --work-dir "$WORK_DIR" "${PROVIDER_ARGUMENTS[@]}" --email "$EMAIL" --agree-tos --config-dir "$CERT_DIR" --work-dir "$WORK_DIR" --preferred-challenges "$CHALLENGE" "${DOMAIN_ARR[@]}"
    else
        certbot certonly --non-interactive --standalone --email "$EMAIL" --agree-tos --config-dir "$CERT_DIR" --work-dir "$WORK_DIR" --preferred-challenges "$CHALLENGE" "${DOMAIN_ARR[@]}"
    fi
else
    certbot renew --non-interactive --config-dir "$CERT_DIR" --work-dir "$WORK_DIR" --preferred-challenges "$CHALLENGE"
fi

# copy certs to store
cp "$CERT_DIR"/live/*/privkey.pem "/ssl/$KEYFILE"
cp "$CERT_DIR"/live/*/fullchain.pem "/ssl/$CERTFILE"
