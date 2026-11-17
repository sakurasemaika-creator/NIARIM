#!/usr/bin/env bash
set -euo pipefail

destination="${1:?usage: bash scripts/prepare-reward-country-layer.sh NEW_OUTPUT_DIRECTORY}"
edition=2026-11
expected_sha1=09eea8433fe3eed71984fd6aac9d8ab3d9ca51f0
source="https://download.db-ip.com/free/dbip-country-lite-$edition.mmdb.gz"
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT

curl --fail --silent --show-error --location --retry 2 --connect-timeout 15 \
  --max-time 120 --proto '=https' --proto-redir '=https' \
  --output "$staging/country.mmdb.gz" "$source"
printf '%s  %s\n' "$expected_sha1" "$staging/country.mmdb.gz" | sha1sum --check
mkdir "$staging/layer"
gzip -dc "$staging/country.mmdb.gz" > "$staging/layer/country.mmdb"
node - "$staging/layer/country.mmdb" <<'JS'
const assert = require('node:assert/strict');
const { open } = require('maxmind');

(async () => {
  const db = await open(process.argv[2]);
  assert.equal(db.get('8.8.8.8')?.country?.iso_code, 'US');
  assert.match(db.get('2001:4860:4860::8888')?.country?.iso_code ?? '', /^[A-Z]{2}$/);
})().catch(error => { console.error(error); process.exitCode = 1; });
JS
cat > "$staging/layer/ATTRIBUTION.txt" <<TXT
IP Geolocation by DB-IP (IP to Country Lite, $edition).
Data source: https://db-ip.com/db/download/ip-to-country-lite
Download: $source
License: Creative Commons Attribution 4.0 International, https://creativecommons.org/licenses/by/4.0/
The database was decompressed and renamed to country.mmdb. Its contents are unmodified.
TXT
mkdir -p "$(dirname "$destination")"
mkdir "$destination"
cp "$staging/layer/country.mmdb" "$staging/layer/ATTRIBUTION.txt" "$destination/"
