#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/home/inside" "$fixture/outside" "$fixture/claude/cache"
awk '/^if \[ "\$APPLY" = 1 \]; then/ { exit } { print }' "$root/freespace" > "$fixture/definitions.bash"
HOME="$fixture/home" FREESPACE_CONFIG=/dev/null /bin/bash -s -- "$fixture/definitions.bash" "$fixture" <<'PROBE'
fixture_root="$(cd "$2" && pwd -P)"
HOME="$(cd "$HOME" && pwd -P)"
source "$1" --only worktrees --scan "$HOME"
CLAUDE_TMP="$fixture_root/claude"
outside="$fixture_root/outside"
ln -s "$outside" "$HOME/escape"
ln -s "$HOME/inside" "$HOME/alias"
printf 'keep\n' > "$outside/file"
printf 'remove\n' > "$HOME/inside/file"
# Intercept rm for all boundary cases; no real files are deleted here.
# Use a fixed log path, avoiding rm's positional arguments.
log="$fixture_root/rm.log"
rm() { printf '%s\n' "$*" >> "$log"; }
APPLY=1
for p in "$HOME/../outside" "$HOME/escape/file" "$HOME/escape" "$HOME" "$HOME/inside/.." / "$CLAUDE_TMP" "$outside/file" "$HOME/alias"; do
  remove "$p"
done
[ ! -e "$log" ] || { echo 'FAIL: unsafe path reached rm' >&2; exit 1; }
remove "$HOME/alias/file" "$CLAUDE_TMP/cache"
[ "$(wc -l < "$log" | tr -d ' ')" = 2 ] || exit 1
[[ "$(cat "$log")" == *"$HOME/inside/file"* ]] || exit 1
APPLY=0
remove "$HOME/inside/file"
[ "$(wc -l < "$log" | tr -d ' ')" = 2 ] || exit 1
# Change the alias between the selection check and the deletion check.
APPLY=1
# A marker persists across command substitutions, unlike shell variables.
marker="$fixture_root/resolved"
resolved_removal_path() {
  if [ -e "$marker" ]; then printf '%s\n' "$outside/file";
  else touch "$marker"; printf '%s\n' "$HOME/inside/file"; fi
}
remove "$HOME/inside/file"
[ "$(wc -l < "$log" | tr -d ' ')" = 2 ] || exit 1
PROBE
echo 'Removal scope tests passed.'
