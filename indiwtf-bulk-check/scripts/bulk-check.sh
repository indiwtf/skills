#!/usr/bin/env bash
# bulk-check.sh — check many domains against the Indiwtf API and emit CSV.
#
#   ./bulk-check.sh example.com github.com
#   ./bulk-check.sh -f domains.txt -c 8 -o report.csv
#   cat domains.txt | ./bulk-check.sh
#
# Token: -t flag, $INDIWTF_TOKEN, or ~/.indiwtf/config.json.
# Output: CSV on stdout (or -o FILE), summary on stderr.
# Quota:  one check per unique domain; refuses to start if the account's
#         remaining monthly quota is lower than the number of domains.
set -uo pipefail

API_BASE="${INDIWTF_API_BASE:-https://indiwtf.com/api}"
CONCURRENCY=4
OUT=""
FILE=""
TOKEN="${INDIWTF_TOKEN:-}"
FORCE=0

usage() {
  cat >&2 <<'EOF'
usage: bulk-check.sh [-t TOKEN] [-f FILE] [-c N] [-o OUT.csv] [--force] [domain...]

  -t TOKEN   API token (default: $INDIWTF_TOKEN or ~/.indiwtf/config.json)
  -f FILE    read domains from FILE (one per line, # comments allowed)
  -c N       concurrent requests (default 4, max 16)
  -o OUT     write CSV to OUT instead of stdout
  --force    skip the remaining-quota preflight check
EOF
}

# Internal single-domain worker, invoked by xargs below.
if [ "${1:-}" = "--one" ]; then
  domain="$2"
  token="$3"
  base="$4"
  body=$(curl -sS -m 20 --get \
    --data-urlencode "domain=${domain}" \
    --data-urlencode "token=${token}" \
    "${base}/check" 2>/dev/null)
  if [ -z "$body" ]; then
    printf '%s,,,,request failed\n' "$domain"
    exit 0
  fi
  python3 -c '
import csv, json, sys
domain, raw = sys.argv[1], sys.argv[2]
w = csv.writer(sys.stdout, lineterminator="\n")
try:
    data = json.loads(raw)
except ValueError:
    w.writerow([domain, "", "", "", raw.strip()[:200]])
    sys.exit()
if "error" in data:
    w.writerow([domain, "", "", "", data["error"]])
else:
    w.writerow([
        data.get("domain", domain),
        data.get("status", ""),
        data.get("ip", ""),
        data.get("checked_at", ""),
        "",
    ])
' "$domain" "$body"
  exit 0
fi

while [ $# -gt 0 ]; do
  case "$1" in
    -t) TOKEN="$2"; shift 2 ;;
    -f) FILE="$2"; shift 2 ;;
    -c) CONCURRENCY="$2"; shift 2 ;;
    -o) OUT="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -*) echo "unknown flag: $1" >&2; usage; exit 2 ;;
    *) break ;;
  esac
done

command -v curl >/dev/null || { echo "curl is required" >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 1; }

if [ -z "$TOKEN" ] && [ -r "$HOME/.indiwtf/config.json" ]; then
  TOKEN=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("token",""))' \
    "$HOME/.indiwtf/config.json" 2>/dev/null)
fi
if [ -z "$TOKEN" ]; then
  echo "no API token: pass -t, set INDIWTF_TOKEN, or run 'indiwtf auth <token>'" >&2
  exit 1
fi

case "$CONCURRENCY" in
  ''|*[!0-9]*) echo "-c must be a number" >&2; exit 2 ;;
esac
[ "$CONCURRENCY" -lt 1 ] && CONCURRENCY=1
[ "$CONCURRENCY" -gt 16 ] && CONCURRENCY=16

# Collect domains: positional args, -f file, else stdin.
collect() {
  if [ $# -gt 0 ]; then
    printf '%s\n' "$@"
  elif [ -n "$FILE" ]; then
    cat -- "$FILE"
  elif [ ! -t 0 ]; then
    cat
  fi
}

# Normalize (strip scheme, path, whitespace, lowercase), drop blanks/comments,
# and de-duplicate while preserving order — every duplicate would cost quota.
DOMAINS=$(collect "$@" | python3 -c '
import re, sys
seen = set()
for line in sys.stdin:
    d = line.strip().lower()
    if not d or d.startswith("#"):
        continue
    d = re.sub(r"^[a-z][a-z0-9+.-]*://", "", d)
    d = d.split("/")[0].split("?")[0].split("@")[-1].split(":")[0]
    if d and d not in seen:
        seen.add(d)
        print(d)
')

COUNT=$(printf '%s' "$DOMAINS" | grep -c . || true)
if [ "$COUNT" -eq 0 ]; then
  echo "no domains given" >&2
  usage
  exit 2
fi

# Preflight: never start a batch that would blow through the monthly quota.
if [ "$FORCE" -eq 0 ]; then
  remaining=$(curl -sS -m 15 --get --data-urlencode "token=${TOKEN}" "${API_BASE}/usage" 2>/dev/null \
    | python3 -c 'import json,sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit()
print(d.get("usage", {}).get("remaining", {}).get("monthly", ""))' 2>/dev/null)
  if [ -n "$remaining" ] && [ "$remaining" -lt "$COUNT" ] 2>/dev/null; then
    echo "quota: $remaining check(s) remaining this month, $COUNT requested — aborting (use --force to override)" >&2
    exit 3
  fi
  [ -n "$remaining" ] && echo "quota: $remaining remaining, checking $COUNT domain(s)" >&2
fi

SELF=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
RESULTS=$(mktemp)
trap 'rm -f "$RESULTS"' EXIT

printf '%s\n' "$DOMAINS" \
  | xargs -P "$CONCURRENCY" -I{} "$SELF" --one {} "$TOKEN" "$API_BASE" \
  >"$RESULTS"

{
  echo "domain,status,ip,checked_at,error"
  sort "$RESULTS"
} | if [ -n "$OUT" ]; then cat >"$OUT"; else cat; fi

blocked=$(grep -c ',blocked,' "$RESULTS" || true)
allowed=$(grep -c ',allowed,' "$RESULTS" || true)
errors=$((COUNT - blocked - allowed))
echo "done: $COUNT checked — $blocked blocked, $allowed allowed, $errors error(s)" >&2
[ -n "$OUT" ] && echo "csv: $OUT" >&2
exit 0
