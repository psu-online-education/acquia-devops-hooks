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

drush maint:set 0

# Flush drupal cache.
drush cr

# Get the current domain.
domain=$(drush php:eval "echo \Drupal::service('settings')->get('current_fqdn');")

# Flush varnish cache.
drush p:invalidate everything --uri="$domain" --no-interaction

# If there are Cloudflare credentials configured, flush the CDN cache.
cf_zone="/mnt/gfs/$AH_SITE_NAME/nobackup/cloudflare.zone"
cf_key="/mnt/gfs/$AH_SITE_NAME/nobackup/cloudflare.key"

if [ -f "$cf_zone" ] && [ -f "$cf_key" ]; then

  # Flush CDN cache.
  raw_result=$(
    curl -sX POST "https://api.cloudflare.com/client/v4/zones/$(cat "$cf_zone")/purge_cache" \
    -H "Authorization: Bearer $(cat "$cf_key")" \
    -H "Content-Type: application/json" \
    -d "{\"hosts\": [\"$domain\"]}"
  )

  echo "$raw_result"

  [[ "$(jq -r '.success' <<< "$raw_result")" == "true" ]]
fi
