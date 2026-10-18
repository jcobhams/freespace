#!/usr/bin/env bash
# install.sh - put freespace on your PATH and add its skill to your AI coding agents.
#
# From a clone:   ./install.sh [--uninstall]
# Without one:    curl -fsSL https://raw.githubusercontent.com/jcobhams/freespace/master/install.sh | bash
#                 curl -fsSL .../install.sh | bash -s -- --uninstall
#
# Run from a clone, it links to the clone. Piped from curl, it downloads freespace
# into ~/.local/share/freespace ($FREESPACE_HOME) first, and running it again updates
# that copy. $FREESPACE_REF picks a branch or tag (default master).
#
# The command goes in ~/.local/bin, or in $FREESPACE_BIN when set. The skill is
# linked for each agent set up on this machine: Claude Code (~/.claude/skills, and
# $CLAUDE_CONFIG_DIR/skills when set), Codex and Gemini CLI (~/.agents/skills) and
# Grok (~/.grok/skills).

set -uo pipefail

REPO="jcobhams/freespace"

# Everything runs from main, so a download cut off halfway runs nothing.
main() {
  local uninstall=0 src here bin found=0
  case "${1:-}" in
    "") ;;
    --uninstall) uninstall=1 ;;
    -h | --help) usage; return 0 ;;
    *) echo "Unknown option: $1" >&2; return 1 ;;
  esac

  src="${BASH_SOURCE[0]:-}"
  if [ -n "$src" ] && [ -f "$(dirname "$src")/freespace" ]; then
    here="$(cd "$(dirname "$src")" && pwd)"
  else
    here="${FREESPACE_HOME:-$HOME/.local/share/freespace}"
    if [ "$uninstall" = 0 ]; then
      download "$here" || return 1
    fi
  fi
  bin="${FREESPACE_BIN:-$HOME/.local/bin}"

  link "$uninstall" "$here/freespace" "$bin/freespace"
  if [ -d "$HOME/.claude" ]; then
    link "$uninstall" "$here/skills/freespace" "$HOME/.claude/skills/freespace"
    found=1
  fi
  # Claude Code reads its config from CLAUDE_CONFIG_DIR instead when that is set.
  if [ -n "${CLAUDE_CONFIG_DIR:-}" ] && [ -d "$CLAUDE_CONFIG_DIR" ] && [ "$CLAUDE_CONFIG_DIR" != "$HOME/.claude" ]; then
    link "$uninstall" "$here/skills/freespace" "$CLAUDE_CONFIG_DIR/skills/freespace"
    found=1
  fi
  if [ -d "$HOME/.codex" ] || [ -d "$HOME/.gemini" ] || [ -d "$HOME/.agents" ]; then
    link "$uninstall" "$here/skills/freespace" "$HOME/.agents/skills/freespace"
    found=1
  fi
  if [ -d "$HOME/.grok" ]; then
    link "$uninstall" "$here/skills/freespace" "$HOME/.grok/skills/freespace"
    found=1
  fi

  if [ "$uninstall" = 1 ]; then
    # Only remove a copy this script downloaded, never a clone.
    if [ "$here" = "${FREESPACE_HOME:-$HOME/.local/share/freespace}" ] && [ -f "$here/.freespace-download" ]; then
      rm -rf "$here"
      echo "removed $(tilde "$here")"
    fi
    return 0
  fi

  [ "$found" = 1 ] || echo "No Claude Code, Codex, Gemini CLI or Grok setup found, so the skill was not linked."
  case ":$PATH:" in
    *":$bin:"*) ;;
    *) echo "Add $(tilde "$bin") to your PATH to run freespace from any folder." ;;
  esac
  echo "Restart your agent sessions to load the skill."
}

usage() {
  sed -n '2,14p' "${BASH_SOURCE[0]:-/dev/null}" 2>/dev/null | sed 's/^# \{0,1\}//'
}

tilde() { printf '%s' "${1/#$HOME/~}"; }

# download DEST: fetches the repo into DEST, replacing an earlier download.
download() {
  local dest="$1" ref="${FREESPACE_REF:-master}" tmp
  if [ -e "$dest" ] && [ ! -f "$dest/.freespace-download" ]; then
    echo "$(tilde "$dest") already exists and was not made by this installer. Set FREESPACE_HOME to install somewhere else." >&2
    return 1
  fi
  command -v curl >/dev/null && command -v tar >/dev/null || {
    echo "Installing needs curl and tar." >&2
    return 1
  }
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/freespace.XXXXXX")" || return 1
  if ! curl -fsSL "https://codeload.github.com/$REPO/tar.gz/$ref" | tar -xz -C "$tmp" --strip-components 1; then
    echo "Could not download $REPO at $ref." >&2
    rm -rf "$tmp"
    return 1
  fi
  if [ ! -x "$tmp/freespace" ]; then
    echo "The download did not contain the freespace script." >&2
    rm -rf "$tmp"
    return 1
  fi
  printf '%s\n' "$ref" >"$tmp/.freespace-download"
  mkdir -p "$(dirname "$dest")"
  rm -rf "$dest"
  mv "$tmp" "$dest"
  echo "downloaded freespace ($ref) to $(tilde "$dest")"
}

# link UNINSTALL TARGET LINK: points LINK at TARGET, or removes it when UNINSTALL is 1.
# Leaves anything that is not one of our links alone.
link() {
  local uninstall="$1" target="$2" path="$3"
  if [ "$uninstall" = 1 ]; then
    if [ -L "$path" ] && [ "$(readlink "$path")" = "$target" ]; then
      rm "$path"
      echo "removed $(tilde "$path")"
    fi
    return 0
  fi
  if [ -e "$path" ] && [ ! -L "$path" ]; then
    echo "skipped $(tilde "$path"): something else is already there"
    return 0
  fi
  mkdir -p "$(dirname "$path")"
  ln -sfn "$target" "$path"
  echo "linked $(tilde "$path")"
}

main "$@"
