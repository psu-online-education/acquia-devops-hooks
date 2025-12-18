#!/bin/bash

# Abort if anything goes wrong.
set -e

# Flush drupal cache.
drush cr

# Run database updates.
drush updb --no-interaction

# Import configuration (twice).
drush cim --no-interaction
drush cim --no-interaction

# Sanitize the database (non-production only).
if [[ -v AH_NON_PRODUCTION ]]; then
  drush sql-sanitize \
    --sanitize-email=%name@example.com \
    --sanitize-password=no
fi

# Flush drupal cache.
drush cr

# Get the current domain.
domain=$(drush php:eval "echo \Drupal::service('settings')->get('current_fqdn');")

# Flush varnish cache.
drush p:invalidate everything --uri="$domain" --no-interaction

# If there are Cloudflare credentials configured, flush the CDN cache.
cf_credentials="/mnt/gfs/$AH_SITE_NAME/nobackup/.cloudflare/credentials.json"

if [ -f "$cf_credentials" ]; then

  zone="$(jq -r '.zoneid' $cf_credentials)"
  email="$(jq -r '.email' $cf_credentials)"
  apikey="$(jq -r '.apikey' $cf_credentials)"

  # Flush CDN cache.
  raw_result=$(
    curl -sX POST "https://api.cloudflare.com/client/v4/zones/$zone/purge_cache" \
    -H "X-Auth-Email: $email" \
    -H "X-Auth-Key: $apikey" \
    -H "Content-Type: application/json" \
    -d "{\"hosts\": [\"$domain\"]}"
  )

  echo "$raw_result"

  [[ "$(jq -r '.success' <<< "$raw_result")" == "true" ]]
fi
