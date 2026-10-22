#!/usr/bin/env bash
# Parser-only tests: never load or execute cleanup code.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
awk '/^for n in / { exit } { print }' "$root/freespace" > "$fixture/parser.bash"
cat >> "$fixture/parser.bash" <<'PROBE'
printf 'APPLY=%s ASK=%s DAYS=%s UNMERGED=%s DOCKER=%s\n' "$APPLY" "$ASK" "$DAYS" "$INCLUDE_UNMERGED" "$DOCKER_ALL"
printf 'EXCLUDE=%s\n' ${EXCLUDES[@]+"${EXCLUDES[@]}"}
PROBE

reject() {
  printf '%s\n' "$1" > "$fixture/options"
  if FREESPACE_CONFIG="$fixture/options" /bin/bash "$fixture/parser.bash" > "$fixture/output" 2>&1; then
    echo "FAIL: accepted config: $1" >&2
    exit 1
  fi
  if rg -q '^APPLY=' "$fixture/output"; then
    echo 'FAIL: invalid config reached parser probe' >&2
    exit 1
  fi
}
for line in '--apply' '--ask' '--apply --include-unmerged' '--ask --docker-all' \
  '--include-unmerged --apply' '--docker-all --ask' '--days' '--exclude' \
  '--days --apply' '--unknown' '--days 2 --apply'; do
  reject "$line"
done
reject $'--days\n--apply'
reject $'--include-unmerged\t--apply'
reject $'--ask\t--docker-all'

cat > "$fixture/options" <<'CONFIG'
  # leading whitespace and blank lines are supported

--days 30
--include-unmerged
--docker-all
--exclude ~/a folder with spaces
CONFIG
printf '\t--scan\t~/another folder\n' >> "$fixture/options"
output="$(FREESPACE_CONFIG="$fixture/options" /bin/bash "$fixture/parser.bash" --days 7)"
[[ "$output" == *'APPLY=0 ASK=0 DAYS=7 UNMERGED=1 DOCKER=1'* ]]
[[ "$output" == *"EXCLUDE=$HOME/a folder with spaces"* ]]
for flag in --apply --ask; do
  output="$(FREESPACE_CONFIG="$fixture/options" /bin/bash "$fixture/parser.bash" "$flag")"
  [[ "$output" == *'APPLY=1'* ]]
  if [ "$flag" = --ask ]; then [[ "$output" == *'ASK=1'* ]]; fi
done
printf '%s' '--days 12' > "$fixture/options"
output="$(FREESPACE_CONFIG="$fixture/options" /bin/bash "$fixture/parser.bash")"
[[ "$output" == *'APPLY=0 ASK=0 DAYS=12'* ]]
echo 'Config parser tests passed.'
