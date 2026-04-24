#!/usr/bin/env bash
# economist-kobo-sync — macOS setup wizard
# Run once: bash install-macos.sh
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m  %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m  %s\n' "$*"; }
ask()  { printf '\033[1m%s\033[0m ' "$*"; }

echo ""
bold "════════════════════════════════════════════════════"
bold " Economist → Kobo Clara Color — macOS setup wizard"
bold "════════════════════════════════════════════════════"
echo ""
info "This sets up:"
info "  • Calibre-Web — runs on your Mac, syncs books to your Kobo over WiFi"
info "  • A weekly job that downloads the Economist every Friday at 07:00"
echo ""

# ── 1. Calibre ────────────────────────────────────────────────────────────────
bold "Step 1 of 6 — Calibre"
if [[ -x /Applications/calibre.app/Contents/MacOS/ebook-convert ]]; then
  ok "Calibre is installed."
  export PATH="/Applications/calibre.app/Contents/MacOS:$PATH"
elif command -v ebook-convert &>/dev/null; then
  ok "Calibre is on PATH."
else
  echo ""
  info "Calibre is not installed. Download it from:"
  info "  https://calibre-ebook.com/download_osx"
  info "Install it, then re-run this script."
  echo ""
  exit 1
fi

# Verify the Calibre library exists (Calibre creates it on first launch)
CALIBRE_LIBRARY="$HOME/Calibre Library"
if [[ ! -d "$CALIBRE_LIBRARY" ]]; then
  warn "No Calibre library found at '$CALIBRE_LIBRARY'."
  info "Open the Calibre app once — it will create the library automatically."
  info "Then re-run this script."
  echo ""
  exit 1
fi
ok "Calibre library: $CALIBRE_LIBRARY"
echo ""

# ── 2. Python virtual environment ─────────────────────────────────────────────
bold "Step 2 of 6 — Python environment"
if [[ ! -d "$DIR/venv" ]]; then
  info "Creating virtual environment…"
  python3 -m venv "$DIR/venv"
  ok "Virtual environment created."
else
  ok "Virtual environment already exists."
fi

info "Installing dependencies (this may take a minute)…"
"$DIR/venv/bin/pip" install -q -r "$DIR/requirements.txt"
ok "Dependencies installed."
echo ""

# ── 3. Configuration ──────────────────────────────────────────────────────────
bold "Step 3 of 6 — Configuration"
echo ""

write_env=true
if [[ -f "$DIR/.env" ]]; then
  ask "A .env file already exists. Overwrite it? [y/N]"
  read -r overwrite
  [[ "$overwrite" =~ ^[Yy]$ ]] || write_env=false
fi

if $write_env; then
  info "Enter your Economist account details:"
  ask "  Economist email:"
  read -r econ_email
  ask "  Economist password:"
  read -rs econ_pass; echo ""

  cat > "$DIR/.env" <<EOF
ECONOMIST_EMAIL=${econ_email}
ECONOMIST_PASSWORD=${econ_pass}

DELIVERY_METHOD=calibredb
CALIBRE_LIBRARY=${CALIBRE_LIBRARY}
CALIBRE_BIN=/Applications/calibre.app/Contents/MacOS

DOWNLOAD_DIR=${HOME}/Downloads/Economist
EOF
  chmod 600 "$DIR/.env"
  ok ".env written (mode 600 — readable only by you)."
else
  ok "Keeping existing .env."
fi
echo ""

# ── 4. Start Calibre-Web ──────────────────────────────────────────────────────
bold "Step 4 of 6 — Calibre-Web first-time setup"
echo ""

mkdir -p "$DIR/.calibreweb"

# Install the Calibre-Web launchd agent so it starts on login
mkdir -p "$LAUNCH_AGENTS"
CW_PLIST="$LAUNCH_AGENTS/com.economist.calibreweb.plist"
sed "s|INSTALL_DIR|$DIR|g" "$DIR/com.economist.calibreweb.plist" > "$CW_PLIST"
launchctl unload "$CW_PLIST" 2>/dev/null || true
launchctl load -w "$CW_PLIST"

ok "Calibre-Web started on http://localhost:8083"
echo ""
info "Complete the one-time Calibre-Web setup in your browser:"
info ""
info "  1. Open http://localhost:8083 — you'll see a setup screen"
info "  2. Set the Calibre library path to:"
info "       $CALIBRE_LIBRARY"
info "  3. Click 'Save' — log in with  admin / admin123"
info "  4. Go to Admin (top-right) → Edit Basic Configuration"
info "        → Feature Configuration"
info "        → Enable Kobo Sync  ✓  → Save"
info "  5. Go to Admin → Edit Users → admin → scroll to 'Kobo Sync Token'"
info "        → copy the token shown (you'll need it in Step 6)"
echo ""
ask "Press Enter once you've completed the Calibre-Web setup…"
read -r

echo ""

# ── 5. Test download ──────────────────────────────────────────────────────────
bold "Step 5 of 6 — Test download"
info "Downloading the latest Economist to verify your subscription credentials…"
info "(Takes 2–4 minutes while Calibre fetches articles.)"
echo ""

if CALIBRE_WEB_HOME="$DIR/.calibreweb" "$DIR/venv/bin/python3" "$DIR/sync.py" --download; then
  echo ""
  ok "Download succeeded."
else
  echo ""
  warn "Download failed. Check your Economist email/password in .env"
  info "Fix it, then re-run: bash install-macos.sh"
  exit 1
fi
echo ""

# ── 6. Weekly sync agent ──────────────────────────────────────────────────────
bold "Step 6 of 6 — Weekly scheduler"
SYNC_PLIST="$LAUNCH_AGENTS/com.economist.kobo-sync.plist"
sed "s|INSTALL_DIR|$DIR|g" "$DIR/com.economist.kobo-sync.plist" > "$SYNC_PLIST"
launchctl unload "$SYNC_PLIST" 2>/dev/null || true
launchctl load -w "$SYNC_PLIST"

ok "Weekly sync scheduled — every Friday at 07:00."
echo ""

bold "════════════════════════════════════════════════════"
bold " Almost there — one last step on your Kobo"
bold "════════════════════════════════════════════════════"
echo ""
info "Plug your Kobo Clara Color into your Mac via USB, then run:"
info ""
info "    bash setup-kobo.sh"
info ""
info "That tells your Kobo to sync with Calibre-Web over WiFi."
info "You only need to do this once."
echo ""
info "After that:"
info "  • Every Friday at 07:00 the Economist downloads automatically"
info "  • When your Kobo is on the same WiFi as your Mac, it syncs the new issue"
info "  • No cable needed after today"
echo ""
info "Useful commands:"
info "  Run sync now:      bash run.sh"
info "  Watch logs:        tail -f $DIR/calibreweb.log"
info "  Weekly sync log:   tail -f $DIR/economist-kobo-sync.log"
echo ""
