#!/usr/bin/env bash
# Installer for the "textfix" SwiftBar plugin (on-device grammar fixer).
#
# One-liner:
#   curl -fsSL https://raw.githubusercontent.com/spacegrowth/textfix/main/install.sh | bash
#
# Re-run any time to update to the latest version. Idempotent.
#
# It builds the engine from main.swift and installs both files into SwiftBar's
# plugin folder:
#   $DIR/textfix.1d.sh   ← the plugin (menu-bar icon + global hotkey)
#   $DIR/.lib/textfix    ← the compiled engine (hidden in .lib/ so SwiftBar
#                          doesn't run it as its own stray "?" menu-bar plugin)
set -euo pipefail

REPO="spacegrowth/textfix"
PLUGIN="textfix.1d.sh"
TARBALL="https://github.com/${REPO}/archive/refs/heads/main.tar.gz"
BUNDLE_ID="com.ameba.SwiftBar"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '\033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!\033[0m %s\n' "$*"; }
die()  { printf '\033[31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

# ── options ──────────────────────────────────────────────────────
# --local installs from THIS checkout instead of downloading main — for testing
# local changes before they're committed/pushed. Same file placement either way.
LOCAL=0
for arg in "$@"; do
  case "$arg" in
    --local) LOCAL=1 ;;
    *)       die "Unknown option: $arg (supported: --local)" ;;
  esac
done

bold "Installing the textfix SwiftBar plugin…"

# ── prerequisites ────────────────────────────────────────────────
[ "$(uname)" = "Darwin" ] || die "macOS only."
command -v swiftc >/dev/null 2>&1 || die "swiftc not found. Install Xcode Command Line Tools: xcode-select --install"
command -v curl   >/dev/null 2>&1 || die "curl not found."
command -v tar    >/dev/null 2>&1 || die "tar not found."

# The on-device model needs macOS 26+ on Apple Silicon with Apple Intelligence.
osmajor="$(sw_vers -productVersion | cut -d. -f1)"
[ "${osmajor:-0}" -ge 26 ] 2>/dev/null || warn "macOS 26+ recommended — the on-device model may be unavailable on older systems."

# SwiftBar is required to *run* the plugin, but not to place the files. Warn, don't block.
if [ -d "/Applications/SwiftBar.app" ] || [ -d "$HOME/Applications/SwiftBar.app" ]; then
  ok "SwiftBar found"
else
  warn "SwiftBar not installed. Get it with:  brew install --cask swiftbar   (or https://swiftbar.app)"
fi

# ── resolve SwiftBar's plugin folder ─────────────────────────────
DIR="$(defaults read "$BUNDLE_ID" PluginDirectory 2>/dev/null || true)"
if [ -z "$DIR" ]; then
  DIR="$HOME/.swiftbar"
  warn "SwiftBar plugin folder not set yet — defaulting to $DIR"
  defaults write "$BUNDLE_ID" PluginDirectory "$DIR" 2>/dev/null \
    && ok "Pointed SwiftBar at $DIR (takes effect when SwiftBar (re)starts)" \
    || warn "Could not preset SwiftBar's plugin folder — set it in SwiftBar ▸ Preferences."
fi
mkdir -p "$DIR/.lib"

# ── resolve source: local checkout (--local) or download main ────
# Both paths end with $SRC holding main.swift + textfix.1d.sh, so the
# build + place-the-files steps below are identical regardless of source.
if [ "$LOCAL" -eq 1 ]; then
  SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  bold "Installing from local checkout: $SRC"
else
  TMPD="$(mktemp -d "${TMPDIR:-/tmp}/textfix.XXXXXX")"
  trap 'rm -rf "$TMPD"' EXIT
  bold "Downloading latest…"
  curl -fsSL "$TARBALL" | tar -xz -C "$TMPD" --strip-components=1 \
    || die "Download/extract failed: $TARBALL"
  SRC="$TMPD"
fi

[ -f "$SRC/main.swift" ] && [ -f "$SRC/$PLUGIN" ] \
  || die "Source missing expected files — aborting (nothing changed)."

# ── build the engine (into a temp file, so a failure changes nothing) ──
bold "Building the engine…"
BUILT="$(mktemp "${TMPDIR:-/tmp}/textfix-bin.XXXXXX")"
swiftc -O "$SRC/main.swift" -o "$BUILT" || die "Build failed."
strip -x "$BUILT" 2>/dev/null || true   # drop debug symbols / build paths

# ── place the files ──────────────────────────────────────────────
cp "$SRC/$PLUGIN" "$DIR/$PLUGIN"; chmod +x "$DIR/$PLUGIN"
cp "$BUILT" "$DIR/.lib/textfix"; chmod +x "$DIR/.lib/textfix"
rm -f "$BUILT"
ok "Installed → $DIR/$PLUGIN  (+ $DIR/.lib/textfix)"

# ── nudge SwiftBar to reload ─────────────────────────────────────
open "swiftbar://refreshallplugins" >/dev/null 2>&1 || open -a SwiftBar >/dev/null 2>&1 || true

# ── summary ──────────────────────────────────────────────────────
echo
bold "Done."
echo "One-time setup:"
echo "  • Grant SwiftBar Accessibility (System Settings ▸ Privacy & Security ▸"
echo "    Accessibility) so it can copy/paste the selection."
echo "  • Enable Apple Intelligence (needs macOS 26+ on Apple Silicon)."
echo
echo "Use it: select text in any app, press ⌘\`  (or click Fix in the menu)."
echo "Re-run this installer any time to update."
