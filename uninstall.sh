#!/usr/bin/env bash
# Uninstaller for the "textfix" SwiftBar plugin.
#
#   curl -fsSL https://raw.githubusercontent.com/spacegrowth/textfix/main/uninstall.sh | bash
#
# Removes the plugin and its engine. By default it KEEPS your rules at
# ~/.config/textfix. Pass --purge to delete that too.
set -euo pipefail

PLUGIN="textfix.1d.sh"
BUNDLE_ID="com.ameba.SwiftBar"
CFG_DIR="$HOME/.config/textfix"

ok()   { printf '\033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!\033[0m %s\n' "$*"; }

PURGE=0
[ "${1:-}" = "--purge" ] && PURGE=1

DIR="$(defaults read "$BUNDLE_ID" PluginDirectory 2>/dev/null || true)"
[ -n "$DIR" ] || DIR="$HOME/.swiftbar"

removed=0
if [ -e "$DIR/$PLUGIN" ];   then rm -f "$DIR/$PLUGIN";   ok "Removed $DIR/$PLUGIN"; removed=1; fi
if [ -e "$DIR/.lib/textfix" ]; then rm -f "$DIR/.lib/textfix"; ok "Removed $DIR/.lib/textfix"; removed=1; fi
rmdir "$DIR/.lib" 2>/dev/null || true          # drop .lib/ if now empty (leave it if other tools use it)
[ "$removed" = "1" ] || warn "No plugin found in $DIR"

if [ "$PURGE" = "1" ]; then
  rm -rf "$CFG_DIR"
  ok "Purged rules $CFG_DIR"
else
  warn "Kept your rules at $CFG_DIR. Pass --purge to remove them."
fi

open "swiftbar://refreshallplugins" >/dev/null 2>&1 || true
ok "Done."
