import shutil
import smtplib
import subprocess
from email import encoders
from email.mime.base import MIMEBase
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from pathlib import Path

from config import Config


class DeliveryError(Exception):
    pass


# ---------------------------------------------------------------------------
# Calibre-Web delivery (primary wireless method)
# ---------------------------------------------------------------------------
# Adds the EPUB to your local Calibre library via `calibredb add`.
# Calibre-Web serves that library to your Kobo over WiFi — the book appears
# automatically next time the Kobo syncs (no action needed on the device).
# ---------------------------------------------------------------------------

def _send_calibredb(epub_path: Path) -> None:
    cmd = [
        Config.calibredb(),
        "add",
        "--library-path", str(Config.CALIBRE_LIBRARY),
        "--dont-notify-gui",
        str(epub_path),
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)

    if result.returncode != 0:
        stderr = result.stderr.strip()
        raise DeliveryError(
            f"calibredb exited with code {result.returncode}.\n{stderr}"
        )

    print(f"[deliver] Added to Calibre library: {Config.CALIBRE_LIBRARY}")
    print("[deliver] The book will appear on your Kobo next time it syncs over WiFi.")


# ---------------------------------------------------------------------------
# Email delivery — "Send to Kobo"
# ---------------------------------------------------------------------------

def _send_email(epub_path: Path) -> None:
    msg = MIMEMultipart()
    msg["From"] = Config.SMTP_USER
    msg["To"] = Config.KOBO_EMAIL
    msg["Subject"] = epub_path.stem

    msg.attach(MIMEText("Delivered by economist-kobo-sync.", "plain"))

    with open(epub_path, "rb") as fh:
        part = MIMEBase("application", "epub+zip")
        part.set_payload(fh.read())
    encoders.encode_base64(part)
    part.add_header("Content-Disposition", f'attachment; filename="{epub_path.name}"')
    msg.attach(part)

    with smtplib.SMTP(Config.SMTP_HOST, Config.SMTP_PORT) as server:
        server.ehlo()
        server.starttls()
        server.login(Config.SMTP_USER, Config.SMTP_PASSWORD)
        server.send_message(msg)

    print(f"[deliver] Sent '{epub_path.name}' to {Config.KOBO_EMAIL}")
    print("[deliver] The file will appear on your Kobo next time it connects to WiFi.")


# ---------------------------------------------------------------------------
# Dropbox delivery
# ---------------------------------------------------------------------------

def _send_dropbox(epub_path: Path) -> None:
    dest = Config.DROPBOX_PATH / epub_path.name
    Config.DROPBOX_PATH.mkdir(parents=True, exist_ok=True)
    shutil.copy2(epub_path, dest)
    print(f"[deliver] Copied to Dropbox: {dest}")
    print("[deliver] The file will appear on your Kobo next time it syncs Dropbox.")


# ---------------------------------------------------------------------------
# USB delivery
# ---------------------------------------------------------------------------

def _send_usb(epub_path: Path) -> None:
    mount = Config.KOBO_MOUNT_PATH
    if not mount or not mount.exists():
        raise DeliveryError(
            f"Kobo mount path not found: {mount}\n"
            "Connect your Kobo via USB and set KOBO_MOUNT_PATH in .env"
        )
    dest_dir = mount / "Books"
    dest_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(epub_path, dest_dir / epub_path.name)
    print(f"[deliver] Copied to Kobo via USB: {dest_dir / epub_path.name}")
    print("[deliver] Safely eject your Kobo — the book will appear in your library.")


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def deliver(epub_path: Path) -> None:
    method = Config.DELIVERY_METHOD
    if method == "calibredb":
        _send_calibredb(epub_path)
    elif method == "email":
        _send_email(epub_path)
    elif method == "dropbox":
        _send_dropbox(epub_path)
    elif method == "usb":
        _send_usb(epub_path)
    else:
        raise DeliveryError(f"Unknown delivery method: {method}")
