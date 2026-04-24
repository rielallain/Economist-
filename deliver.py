import shutil
import smtplib
from email import encoders
from email.mime.base import MIMEBase
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from pathlib import Path

from config import Config


class DeliveryError(Exception):
    pass


# ---------------------------------------------------------------------------
# Email delivery — "Send to Kobo"
# ---------------------------------------------------------------------------
# Kobo supports receiving EPUB/PDF files by email (similar to Send to Kindle).
# Setup steps:
#   1. Log in at kobo.com → Account → Send to Kobo → Enable & copy your Kobo email address
#   2. Add your sending email address to the approved senders list
#   3. Set KOBO_EMAIL=<your-kobo-address>@send.kobo.com in .env
# ---------------------------------------------------------------------------

def _send_email(epub_path: Path) -> None:
    msg = MIMEMultipart()
    msg["From"] = Config.SMTP_USER
    msg["To"] = Config.KOBO_EMAIL
    msg["Subject"] = epub_path.stem  # Kobo uses the subject as the book title fallback

    msg.attach(MIMEText("Delivered by economist-kobo-sync.", "plain"))

    with open(epub_path, "rb") as fh:
        part = MIMEBase("application", "epub+zip")
        part.set_payload(fh.read())
    encoders.encode_base64(part)
    part.add_header("Content-Disposition", f'attachment; filename="{epub_path.name}"')
    msg.attach(part)

    print(f"[deliver] Connecting to {Config.SMTP_HOST}:{Config.SMTP_PORT}…")
    with smtplib.SMTP(Config.SMTP_HOST, Config.SMTP_PORT) as server:
        server.ehlo()
        server.starttls()
        server.login(Config.SMTP_USER, Config.SMTP_PASSWORD)
        server.send_message(msg)

    print(f"[deliver] Sent '{epub_path.name}' to {Config.KOBO_EMAIL}")
    print("[deliver] The file will appear on your Kobo the next time it connects to WiFi.")


# ---------------------------------------------------------------------------
# Dropbox delivery
# ---------------------------------------------------------------------------
# Kobo devices can sync books from a Dropbox folder.
# Setup steps:
#   1. On your Kobo: Settings → Account → Connect to Dropbox
#   2. Kobo will sync the 'Kobo' folder inside your Dropbox (or the root)
#   3. Set DROPBOX_PATH to that folder in .env
# ---------------------------------------------------------------------------

def _send_dropbox(epub_path: Path) -> None:
    dest = Config.DROPBOX_PATH / epub_path.name
    Config.DROPBOX_PATH.mkdir(parents=True, exist_ok=True)
    shutil.copy2(epub_path, dest)
    print(f"[deliver] Copied to Dropbox: {dest}")
    print("[deliver] The file will appear on your Kobo the next time it syncs Dropbox.")


# ---------------------------------------------------------------------------
# USB delivery (fallback wired method)
# ---------------------------------------------------------------------------

def _send_usb(epub_path: Path) -> None:
    mount = Config.KOBO_MOUNT_PATH
    if not mount or not mount.exists():
        raise DeliveryError(
            f"Kobo mount path not found: {mount}\n"
            "Connect your Kobo via USB and set KOBO_MOUNT_PATH in .env\n"
            "Example: KOBO_MOUNT_PATH=/media/user/KOBOeReader"
        )
    dest_dir = mount / "Books"
    dest_dir.mkdir(parents=True, exist_ok=True)
    dest = dest_dir / epub_path.name
    shutil.copy2(epub_path, dest)
    print(f"[deliver] Copied to Kobo via USB: {dest}")
    print("[deliver] Safely eject your Kobo — the book will appear in your library.")


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def deliver(epub_path: Path) -> None:
    method = Config.DELIVERY_METHOD
    if method == "email":
        _send_email(epub_path)
    elif method == "dropbox":
        _send_dropbox(epub_path)
    elif method == "usb":
        _send_usb(epub_path)
    else:
        raise DeliveryError(f"Unknown delivery method: {method}")
