#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
export HOME="$fixture/home"
export FREESPACE_CONFIG=/dev/null
export GIT_CONFIG_NOSYSTEM=1
mkdir -p "$HOME/scan" "$HOME/outside" "$fixture/external"
repo="$HOME/scan/repo"
git init -q -b main "$repo"
git -C "$repo" -c user.name=Test -c user.email=test@example.invalid -c commit.gpgsign=false commit --allow-empty -qm fixture
add_worktree() {
  git -C "$repo" worktree add -q -b "$1" "$2"
  admin="$(git -C "$2" rev-parse --absolute-git-dir)"
  touch -t 200001010000 "$admin/HEAD" "$admin/logs/HEAD"
}
add_worktree allowed "$HOME/scan/allowed"
add_worktree excluded "$HOME/scan/excluded"
add_worktree outside "$HOME/outside/wt"
add_worktree external "$fixture/external/wt"
ln -s "$HOME/scan/excluded" "$HOME/excluded-alias"
ln -s "$HOME/scan" "$HOME/scan-alias"
# Real deletion is restricted to disposable fixture worktrees. An explicit scan
# outside HOME must still not authorize removal there.
output="$(/bin/bash "$root/freespace" --only worktrees --scan "$HOME/scan-alias/../scan" --scan "$fixture/external" --exclude "$HOME/excluded-alias" --apply)"
[ ! -d "$HOME/scan/allowed" ]
for path in "$HOME/scan/excluded" "$HOME/outside/wt" "$fixture/external/wt"; do
  [ -f "$path/.git" ] || { echo "FAIL: removed protected worktree $path" >&2; exit 1; }
done
[[ "$output" == *'outside cleanup scope'* ]]
# Direct helper checks cover symlinked parents, traversal, boundary prefixes and
# a scope change during confirmation.
awk '/^if \[ "\$APPLY" = 1 \]; then/ { exit } { print }' "$root/freespace" > "$fixture/definitions.bash"
FREESPACE_CONFIG=/dev/null /bin/bash -s -- "$fixture/definitions.bash" "$fixture" <<'PROBE'
source "$1" --only worktrees --scan "$HOME/scan" --exclude "$HOME/scan/excluded"
mkdir -p "$HOME/scan-sibling" "$HOME/scan/new"
ln -s "$HOME/outside" "$HOME/scan/link"
for path in "$HOME" / "$HOME/scan-sibling" "$HOME/scan/../outside/wt" "$HOME/scan/link/wt" "$HOME/scan/excluded"; do
  if worktree_in_scope "$path"; then echo "FAIL: accepted $path" >&2; exit 1; fi
done
worktree_in_scope "$HOME/scan/new" || exit 1
confirm() { EXCLUDES+=("$HOME/scan/new"); }
run() { echo 'FAIL: removal ran after scope changed' >&2; exit 1; }
set_kb 1234
if take_worktree test "$HOME/scan/repo" "$HOME/scan/new"; then exit 1; fi
[ "$TOTAL_KB" = 0 ] || exit 1
PROBE
echo 'Worktree scope tests passed.'
