#!/usr/bin/env bash
# economist-kobo-sync — macOS setup wizard
# Run once: bash install-macos.sh
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
PLIST_NAME="com.economist.kobo-sync"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m  %s\n' "$*"; }
ask()  { printf '\033[1m%s\033[0m ' "$*"; }

echo ""
bold "═══════════════════════════════════════════════════"
bold " Economist → Kobo Clara Color — macOS setup wizard"
bold "═══════════════════════════════════════════════════"
echo ""

# ── 1. Calibre ────────────────────────────────────────────────────────────────
bold "Step 1 of 5 — Calibre"
if command -v ebook-convert &>/dev/null || [[ -x /Applications/calibre.app/Contents/MacOS/ebook-convert ]]; then
  ok "Calibre is installed."
else
  echo ""
  info "Calibre is not installed. Download it from:"
  info "  https://calibre-ebook.com/download_osx"
  info "Install it, then re-run this script."
  echo ""
  exit 1
fi

# Add /Applications/calibre.app to PATH for the rest of the script
if [[ -d /Applications/calibre.app/Contents/MacOS ]]; then
  export PATH="/Applications/calibre.app/Contents/MacOS:$PATH"
fi
echo ""

# ── 2. Python virtual environment ─────────────────────────────────────────────
bold "Step 2 of 5 — Python environment"
if [[ ! -d "$DIR/venv" ]]; then
  info "Creating virtual environment…"
  python3 -m venv "$DIR/venv"
  ok "Virtual environment created."
else
  ok "Virtual environment already exists."
fi

info "Installing Python dependencies…"
"$DIR/venv/bin/pip" install -q -r "$DIR/requirements.txt"
ok "Dependencies installed."
echo ""

# ── 3. Configuration ──────────────────────────────────────────────────────────
bold "Step 3 of 5 — Configuration"
echo ""

if [[ -f "$DIR/.env" ]]; then
  ask "A .env file already exists. Overwrite it? [y/N]"
  read -r overwrite
  [[ "$overwrite" =~ ^[Yy]$ ]] || { ok "Keeping existing .env."; echo ""; }
fi

if [[ ! -f "$DIR/.env" ]] || [[ "${overwrite:-}" =~ ^[Yy]$ ]]; then
  echo ""
  info "Enter your Economist account details:"
  ask "  Economist email:"
  read -r econ_email
  ask "  Economist password:"
  read -rs econ_pass; echo ""

  echo ""
  info "Enter your Gmail details for sending to Kobo:"
  info "  (Gmail App Password required — see https://myaccount.google.com/apppasswords)"
  ask "  Gmail address:"
  read -r gmail_addr
  ask "  Gmail App Password (16 chars, no spaces):"
  read -rs gmail_pass; echo ""

  echo ""
  info "Find your Kobo email address:"
  info "  On the Clara Color: Settings → My account → Send to Kobo"
  info "  It looks like  abc123@send.kobo.com"
  info "  Also add your Gmail address to the approved senders list there."
  ask "  Kobo email address:"
  read -r kobo_email

  cat > "$DIR/.env" <<EOF
ECONOMIST_EMAIL=${econ_email}
ECONOMIST_PASSWORD=${econ_pass}

DELIVERY_METHOD=email

KOBO_EMAIL=${kobo_email}
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=${gmail_addr}
SMTP_PASSWORD=${gmail_pass}

DOWNLOAD_DIR=${HOME}/Downloads/Economist
CALIBRE_BIN=/Applications/calibre.app/Contents/MacOS
EOF
  chmod 600 "$DIR/.env"
  ok ".env written (permissions set to 600 — readable only by you)."
fi
echo ""

# ── 4. Smoke test ─────────────────────────────────────────────────────────────
bold "Step 4 of 5 — Quick test"
info "Running a dry-run to check credentials…"
echo ""
if "$DIR/venv/bin/python3" "$DIR/sync.py" --download; then
  ok "Download succeeded."
else
  echo ""
  info "Download failed. Common causes:"
  info "  • Wrong Economist email or password"
  info "  • Calibre not finding the recipe — check output above"
  info "Fix .env and re-run: bash install-macos.sh"
  exit 1
fi
echo ""

# ── 5. launchd agent (runs every Friday 07:00) ───────────────────────────────
bold "Step 5 of 5 — Weekly scheduler"
mkdir -p "$LAUNCH_AGENTS"

PLIST_DEST="$LAUNCH_AGENTS/$PLIST_NAME.plist"
sed "s|INSTALL_DIR|$DIR|g" "$DIR/com.economist.kobo-sync.plist" > "$PLIST_DEST"

# Unload first in case it was already loaded
launchctl unload "$PLIST_DEST" 2>/dev/null || true
launchctl load -w "$PLIST_DEST"

ok "launchd agent installed — will run every Friday at 07:00."
info "Log file: $DIR/economist-kobo-sync.log"
echo ""

bold "═══════════════════════════════════"
bold " All done!"
bold "═══════════════════════════════════"
echo ""
info "Your Economist will land on your Kobo Clara Color every Friday morning."
info "Make sure your Kobo is connected to WiFi so it can receive the file."
echo ""
info "Useful commands:"
info "  Run now:          bash run.sh"
info "  Download only:    venv/bin/python3 sync.py --download"
info "  View log:         tail -f economist-kobo-sync.log"
info "  Uninstall agent:  launchctl unload ~/Library/LaunchAgents/$PLIST_NAME.plist"
echo ""
