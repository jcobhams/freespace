#!/usr/bin/env bash
# install.sh - put freespace on your PATH and add its skill to your AI coding agents.
#
# Usage: ./install.sh              link the command and the skill
#        ./install.sh --uninstall  remove those links
#
# The command goes in ~/.local/bin, or in $FREESPACE_BIN when set. The skill is
# linked for each agent set up on this machine: Claude Code (~/.claude/skills),
# Codex and Gemini CLI (~/.agents/skills) and Grok (~/.grok/skills).
# Everything is a symlink into this folder, so a git pull updates it.

set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
bin="${FREESPACE_BIN:-$HOME/.local/bin}"
uninstall=0
case "${1:-}" in
  "") ;;
  --uninstall) uninstall=1 ;;
  -h | --help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) echo "Unknown option: $1" >&2; exit 1 ;;
esac

# link TARGET LINK: makes LINK point at TARGET, or removes it with --uninstall.
# Leaves anything that is not one of our links alone.
link() {
  local target="$1" path="$2"
  if [ "$uninstall" = 1 ]; then
    if [ -L "$path" ] && [ "$(readlink "$path")" = "$target" ]; then
      rm "$path"
      echo "removed ${path/#$HOME/~}"
    fi
    return
  fi
  if [ -e "$path" ] && [ ! -L "$path" ]; then
    echo "skipped ${path/#$HOME/~}: something else is already there"
    return
  fi
  mkdir -p "$(dirname "$path")"
  ln -sfn "$target" "$path"
  echo "linked ${path/#$HOME/~}"
}

link "$here/freespace" "$bin/freespace"

found=0
if [ -d "$HOME/.claude" ]; then
  link "$here/skills/freespace" "$HOME/.claude/skills/freespace"
  found=1
fi
if [ -d "$HOME/.codex" ] || [ -d "$HOME/.gemini" ] || [ -d "$HOME/.agents" ]; then
  link "$here/skills/freespace" "$HOME/.agents/skills/freespace"
  found=1
fi
if [ -d "$HOME/.grok" ]; then
  link "$here/skills/freespace" "$HOME/.grok/skills/freespace"
  found=1
fi

[ "$uninstall" = 1 ] && exit 0
[ "$found" = 1 ] || echo "No Claude Code, Codex, Gemini CLI or Grok setup found, so the skill was not linked."
case ":$PATH:" in
  *":$bin:"*) ;;
  *) echo "Add $bin to your PATH to run freespace from any folder." ;;
esac
echo "Restart your agent sessions to load the skill."
