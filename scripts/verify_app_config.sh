#!/usr/bin/env bash
#
# verify_app_config.sh — Fetch the GitHub Pages-hosted app-config.json and
# validate it against the schema UpdateService expects.
#
# Usage:
#   ./scripts/verify_app_config.sh
#   APP_CONFIG_URL=https://your.domain/config.json ./scripts/verify_app_config.sh
#
# Exit codes:
#   0 = reachable, valid JSON, schema fields OK, versions sane
#   1 = network error, invalid JSON, schema mismatch, or version drift

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# Default URL points at the GitHub Pages endpoint the in-app UpdateService
# is expected to use. Override via the env var if you point at a different
# host (e.g. Cloudflare R2 during testing).
DEFAULT_URL="https://senghan1992.github.io/trading_diary/app-config.json"
URL="${APP_CONFIG_URL:-$DEFAULT_URL}"

# Path to the project's pubspec.yaml so we can cross-check that the
# committed `latest_version` matches the build under test.
PUBSPEC="${PUBSPEC_PATH:-pubspec.yaml}"

# Network / parse constraints
FETCH_TIMEOUT=10  # seconds

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

err()  { printf '  ✗ %s\n' "$*" >&2; }
ok()   { printf '  ✓ %s\n' "$*"; }
info() { printf '  · %s\n' "$*"; }
hdr()  { printf '\n\033[1m%s\033[0m\n' "$*"; }

# Pretty-print a key/value pair from a JSON file using jq if available,
# otherwise a tiny grep-based fallback.
json_field() {
  local file="$1" key="$2"
  if command -v jq >/dev/null 2>&1; then
    # `.foo // "<missing>"` returns the string when `.foo` is null OR false
    # (because both are falsy in jq). For version/release gating we need
    # to distinguish "field absent" from "field present and false", so we
    # use `has()` first and stringify the value. Boolean false serializes
    # to "false", which downstream comparisons can match.
    jq -r "if has(\"${key}\") then (.[\"${key}\"] | tostring) else \"<missing>\" end" "$file"
  else
    # Crude fallback: matches "key": "value" at top level. Only used if
    # jq isn't installed — install jq for real verification.
    grep -E "\"${key}\":" "$file" | head -1 | sed -E "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"?([^\",}]+)\"?.*/\1/"
  fi
}

# ---------------------------------------------------------------------------
# 1. Fetch
# ---------------------------------------------------------------------------

hdr "1. Fetching config"
info "URL:    $URL"
info "Timeout: ${FETCH_TIMEOUT}s"

TMP="$(mktemp -t app-config.XXXXXX.json)"
trap 'rm -f "$TMP"' EXIT

HTTP_CODE=$(curl -sS -o "$TMP" -w "%{http_code}" \
  --max-time "$FETCH_TIMEOUT" \
  -H "Accept: application/json" \
  "$URL" || echo "000")

case "$HTTP_CODE" in
  200) ok "HTTP 200 OK" ;;
  404)
    err "HTTP 404 Not Found"
    err "  → GitHub Pages is not serving this URL yet."
    err "  → Did you enable Pages? Settings → Pages → Source: main / /docs"
    err "  → Did you wait ~1 minute after enabling? First deploy takes time."
    exit 1
    ;;
  000)
    err "Network error — could not reach $URL"
    exit 1
    ;;
  *)
    err "HTTP $HTTP_CODE — unexpected response"
    exit 1
    ;;
esac

# ---------------------------------------------------------------------------
# 2. Parse
# ---------------------------------------------------------------------------

hdr "2. Parsing JSON"
if ! command -v jq >/dev/null 2>&1; then
  err "jq is not installed. Install with: brew install jq"
  err "Falling back to grep-based parsing (less strict)."
fi

if command -v jq >/dev/null 2>&1; then
  if ! jq empty "$TMP" 2>/dev/null; then
    err "Response body is not valid JSON"
    cat "$TMP"
    exit 1
  fi
  ok "Body is valid JSON ($(wc -c < "$TMP" | tr -d ' ') bytes)"
else
  if ! ruby -rjson -e "JSON.parse(File.read('$TMP'))" 2>/dev/null; then
    err "Response body is not valid JSON"
    cat "$TMP"
    exit 1
  fi
  ok "Body is valid JSON ($(wc -c < "$TMP" | tr -d ' ') bytes)"
fi

# ---------------------------------------------------------------------------
# 3. Schema
# ---------------------------------------------------------------------------

hdr "3. Schema check"

check_field() {
  local key="$1" type="$2" required="$3"
  local val
  if command -v jq >/dev/null 2>&1; then
    # Use has() so booleans (which jq treats as falsy under `//`) aren't
    # mistaken for missing fields.
    val=$(jq -r "if has(\"${key}\") then (.[\"${key}\"] | tostring) else \"<missing>\" end" "$TMP")
  else
    val=$(json_field "$TMP" "$key")
  fi
  if [[ -z "$val" || "$val" == "<missing>" ]]; then
    if [[ "$required" == "required" ]]; then
      err "  $key: MISSING (required)"
      MISSING=1
    else
      ok "  $key: absent (optional)"
    fi
  else
    ok "  $key: $val ($type)"
  fi
}

MISSING=0
check_field "latest_version"     "string"  required
check_field "minimum_version"    "string"  required
check_field "force_update"       "boolean" required
check_field "update_message_ko"  "string"  optional
check_field "update_message_en"  "string"  optional
check_field "store_url_ios"      "string"  optional
check_field "store_url_android"  "string"  optional

if [[ "$MISSING" == "1" ]]; then
  err "Required fields are missing. UpdateService will treat the config as null and skip the check."
  exit 1
fi

# ---------------------------------------------------------------------------
# 4. Cross-check against pubspec.yaml
# ---------------------------------------------------------------------------

hdr "4. Version cross-check"

if [[ -f "$PUBSPEC" ]]; then
  PUB_VERSION=$(grep -E '^version:' "$PUBSPEC" | head -1 | sed -E 's/^version:[[:space:]]*([^ +]+).*/\1/')
  CFG_LATEST=$(json_field "$TMP" "latest_version")
  info "pubspec.yaml version:  $PUB_VERSION"
  info "config latest_version: $CFG_LATEST"

  # Note: latest_version in config should equal or exceed pubspec. Equal
  # is fine — that's the v1.0 dormant state.
  if [[ "$CFG_LATEST" < "$PUB_VERSION" ]]; then
    err "config latest_version ($CFG_LATEST) is BEHIND pubspec ($PUB_VERSION)"
    err "  → After publishing a new build, bump latest_version in the config"
    exit 1
  else
    ok "config latest_version >= pubspec ($CFG_LATEST >= $PUB_VERSION)"
  fi
else
  info "pubspec.yaml not found at $PUBSPEC — skipping version cross-check"
fi

# ---------------------------------------------------------------------------
# 5. UpdateService integration sanity
# ---------------------------------------------------------------------------

hdr "5. UpdateService integration sanity"
info "If force_update=true OR current < minimum_version, the app will block."
info "For v1.0 with all users on the same build, this should be a no-op."

FORCE=$(json_field "$TMP" "force_update")
MIN=$(json_field "$TMP" "minimum_version")
LATEST=$(json_field "$TMP" "latest_version")

if [[ "$FORCE" == "true" ]]; then
  err "force_update=true — every user below minimum_version will be blocked."
  info "  → If this is intentional (e.g. critical bug), confirm and re-deploy."
else
  ok "force_update=false (no block)"
fi

if [[ -n "$MIN" && "$LATEST" < "$MIN" ]]; then
  err "latest_version ($LATEST) is below minimum_version ($MIN) — every user will be blocked."
  exit 1
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

hdr "✓ All checks passed"
printf '\nFull payload:\n'
if command -v jq >/dev/null 2>&1; then
  jq . "$TMP"
else
  cat "$TMP"
fi