#!/usr/bin/env bash
# One-time setup: points your Kobo Clara Color at the local Calibre-Web server.
# Run this while the Kobo is connected via USB.
#
# Usage: bash setup-kobo.sh
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m  %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m  %s\n' "$*"; }
ask()  { printf '\033[1m%s\033[0m ' "$*"; }

echo ""
bold "══════════════════════════════════════════"
bold " Kobo Clara Color — one-time WiFi setup"
bold "══════════════════════════════════════════"
echo ""
info "This script edits one config file on your Kobo so it syncs"
info "with the Calibre-Web server running on your Mac over WiFi."
info ""
info "You only need to run this once."
echo ""

# ── Find the Kobo mount ───────────────────────────────────────────────────────
KOBO_MOUNT="/Volumes/KOBOeReader"
if [[ ! -d "$KOBO_MOUNT" ]]; then
  warn "Kobo not found at $KOBO_MOUNT"
  info "Make sure your Clara Color is plugged in via USB and its screen is unlocked."
  info "Then re-run: bash setup-kobo.sh"
  exit 1
fi
ok "Kobo found at $KOBO_MOUNT"

# ── Get the Mac's local WiFi IP ───────────────────────────────────────────────
MAC_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)
if [[ -z "$MAC_IP" ]]; then
  warn "Could not detect your Mac's WiFi IP address automatically."
  ask "  Enter your Mac's local IP (e.g. 192.168.1.x):"
  read -r MAC_IP
fi
ok "Mac IP: $MAC_IP"

# ── Get the Calibre-Web Kobo sync token ──────────────────────────────────────
echo ""
bold "Get your Calibre-Web Kobo sync token:"
info ""
info "1. Open http://localhost:8083 in your browser"
info "2. Log in (default: admin / admin123)"
info "3. Go to: Admin → Users → your user → Edit"
info "4. Scroll to 'Kobo Sync Token' and copy the URL shown"
info "   It looks like: http://localhost:8083/kobo/abc123def456"
info "5. Paste just the token part (the last bit after /kobo/)"
info ""
ask "  Kobo sync token:"
read -r TOKEN

if [[ -z "$TOKEN" ]]; then
  warn "No token entered. Aborting."
  exit 1
fi

# Strip a full URL if the user pasted it, keep only the token
TOKEN="${TOKEN##*/}"

SYNC_URL="http://${MAC_IP}:8083/kobo/${TOKEN}"
ok "Sync URL: $SYNC_URL"

# ── Edit the Kobo config file ─────────────────────────────────────────────────
CONF_FILE="$KOBO_MOUNT/.kobo/Kobo/Kobo eReader.conf"

if [[ ! -f "$CONF_FILE" ]]; then
  warn "Could not find Kobo config file at:"
  warn "  $CONF_FILE"
  info "Make sure the Kobo is properly mounted and try again."
  exit 1
fi

# Back up the original
cp "$CONF_FILE" "${CONF_FILE}.bak"
ok "Backed up config to Kobo eReader.conf.bak"

# Use Python for reliable INI editing
python3 - "$CONF_FILE" "$SYNC_URL" <<'PYEOF'
import sys, configparser, pathlib

conf_path = pathlib.Path(sys.argv[1])
sync_url  = sys.argv[2]

# configparser preserves existing keys; RawConfigParser avoids interpolation issues
cfg = configparser.RawConfigParser()
cfg.optionxform = str  # preserve key case
cfg.read(conf_path)

section = "OneStoreServices"
if not cfg.has_section(section):
    cfg.add_section(section)

cfg.set(section, "api_endpoint", sync_url)

with open(conf_path, "w") as fh:
    cfg.write(fh, space_around_delimiters=False)
PYEOF

ok "Kobo config updated."
echo ""

# ── Done ─────────────────────────────────────────────────────────────────────
bold "══════════════════════════════════════════"
bold " Done! Safe to eject your Kobo now."
bold "══════════════════════════════════════════"
echo ""
info "After ejecting:"
info "  1. Make sure your Mac and Kobo are on the same WiFi network"
info "  2. On the Kobo: tap the sync icon (↺) or open a book — it will connect"
info "  3. New Economist editions will appear automatically every Friday"
echo ""
info "If the Kobo can't connect, check that Calibre-Web is running:"
info "  tail -20 $DIR/calibreweb.log"
echo ""
