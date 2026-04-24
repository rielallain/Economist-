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
  if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
    ok "Keeping existing .env."
    echo ""
  fi
fi

if [[ ! -f "$DIR/.env" ]] || [[ "${overwrite:-}" =~ ^[Yy]$ ]]; then

  # Economist credentials
  info "Enter your Economist account details:"
  ask "  Economist email:"
  read -r econ_email
  ask "  Economist password:"
  read -rs econ_pass; echo ""
  echo ""

  # Detect Dropbox folder
  # macOS 12.3+ uses ~/Library/CloudStorage/Dropbox; older clients use ~/Dropbox
  if [[ -d "$HOME/Library/CloudStorage/Dropbox" ]]; then
    dropbox_root="$HOME/Library/CloudStorage/Dropbox"
  elif [[ -d "$HOME/Dropbox" ]]; then
    dropbox_root="$HOME/Dropbox"
  else
    dropbox_root=""
  fi

  if [[ -n "$dropbox_root" ]]; then
    ok "Dropbox found at: $dropbox_root"
    dropbox_path="$dropbox_root/Kobo"
  else
    info "Could not detect Dropbox automatically."
    info "If Dropbox is not installed, download it from https://www.dropbox.com/install"
    ask "  Dropbox folder path (press Enter for ~/Dropbox/Kobo):"
    read -r dropbox_input
    dropbox_path="${dropbox_input:-$HOME/Dropbox/Kobo}"
  fi

  echo ""
  info "Books will be copied to: $dropbox_path"
  info "On your Clara Color: Settings → My account → Dropbox → Connect"
  info "Kobo will sync EPUB files from the root of that connected folder."
  echo ""

  cat > "$DIR/.env" <<EOF
ECONOMIST_EMAIL=${econ_email}
ECONOMIST_PASSWORD=${econ_pass}

DELIVERY_METHOD=dropbox
DROPBOX_PATH=${dropbox_path}

DOWNLOAD_DIR=${HOME}/Downloads/Economist
CALIBRE_BIN=/Applications/calibre.app/Contents/MacOS
EOF
  chmod 600 "$DIR/.env"
  ok ".env written (permissions set to 600 — readable only by you)."
fi
echo ""

# ── 4. Smoke test (download only — no delivery yet) ───────────────────────────
bold "Step 4 of 5 — Quick test"
info "Downloading the latest edition to verify your Economist credentials…"
info "(This may take 2–4 minutes while Calibre fetches articles.)"
echo ""
if "$DIR/venv/bin/python3" "$DIR/sync.py" --download; then
  echo ""
  ok "Download succeeded."
else
  echo ""
  info "Download failed. Common causes:"
  info "  • Wrong Economist email or password in .env"
  info "  • No active Economist digital subscription"
  info "Fix .env and re-run: bash install-macos.sh"
  exit 1
fi
echo ""

# ── 5. launchd agent (runs every Friday 07:00) ───────────────────────────────
bold "Step 5 of 5 — Weekly scheduler"
mkdir -p "$LAUNCH_AGENTS"

PLIST_DEST="$LAUNCH_AGENTS/$PLIST_NAME.plist"
sed "s|INSTALL_DIR|$DIR|g" "$DIR/com.economist.kobo-sync.plist" > "$PLIST_DEST"

launchctl unload "$PLIST_DEST" 2>/dev/null || true
launchctl load -w "$PLIST_DEST"

ok "launchd agent installed — will run every Friday at 07:00."
info "Log file: $DIR/economist-kobo-sync.log"
echo ""

bold "═══════════════════════════════════════════════════"
bold " All done!"
bold "═══════════════════════════════════════════════════"
echo ""
info "Every Friday morning the script will:"
info "  1. Download the new Economist edition via Calibre"
info "  2. Copy it to your Dropbox folder"
info "  3. Your Clara Color will pick it up next time it syncs over WiFi"
echo ""
info "Make sure your Kobo is connected to WiFi and Dropbox is linked"
info "(Settings → My account → Dropbox on the device)."
echo ""
info "Useful commands:"
info "  Run now:        bash run.sh"
info "  Download only:  venv/bin/python3 sync.py --download"
info "  View log:       tail -f $DIR/economist-kobo-sync.log"
info "  Uninstall:      launchctl unload $PLIST_DEST"
echo ""
