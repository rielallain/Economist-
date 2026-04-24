import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()


class Config:
    # Economist subscription credentials
    ECONOMIST_EMAIL = os.getenv("ECONOMIST_EMAIL", "")
    ECONOMIST_PASSWORD = os.getenv("ECONOMIST_PASSWORD", "")

    # Delivery method: "email", "dropbox", or "usb"
    DELIVERY_METHOD = os.getenv("DELIVERY_METHOD", "email")

    # Send to Kobo via email
    # Find your Kobo email in: Kobo account settings → Send to Kobo
    KOBO_EMAIL = os.getenv("KOBO_EMAIL", "")

    # SMTP settings for sending the email
    SMTP_HOST = os.getenv("SMTP_HOST", "smtp.gmail.com")
    SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
    SMTP_USER = os.getenv("SMTP_USER", "")
    SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "")

    # Dropbox delivery: path to the Kobo Books folder in your Dropbox
    # Kobo looks for books in: Dropbox/Books (or wherever you've configured it)
    DROPBOX_PATH = Path(os.getenv("DROPBOX_PATH", "~/Dropbox/Books")).expanduser()

    # USB / mounted Kobo path (e.g. /media/user/KOBOeReader)
    KOBO_MOUNT_PATH = Path(os.getenv("KOBO_MOUNT_PATH", "")).expanduser() if os.getenv("KOBO_MOUNT_PATH") else None

    # Where to save downloaded EPUB files locally
    DOWNLOAD_DIR = Path(os.getenv("DOWNLOAD_DIR", "~/Downloads/Economist")).expanduser()

    # Optional: override calibre binary directory (e.g. /opt/calibre)
    CALIBRE_BIN = os.getenv("CALIBRE_BIN", "")

    def __init__(self):
        pass

    @classmethod
    def ebook_convert(cls) -> str:
        if cls.CALIBRE_BIN:
            return str(Path(cls.CALIBRE_BIN) / "ebook-convert")
        return "ebook-convert"

    @classmethod
    def validate(cls) -> list[str]:
        errors = []
        if not cls.ECONOMIST_EMAIL:
            errors.append("ECONOMIST_EMAIL is not set")
        if not cls.ECONOMIST_PASSWORD:
            errors.append("ECONOMIST_PASSWORD is not set")
        if cls.DELIVERY_METHOD == "email":
            for var in ("SMTP_USER", "SMTP_PASSWORD", "KOBO_EMAIL"):
                if not getattr(cls, var):
                    errors.append(f"{var} is not set (required for email delivery)")
        elif cls.DELIVERY_METHOD == "dropbox":
            pass  # DROPBOX_PATH has a default
        elif cls.DELIVERY_METHOD == "usb":
            if not cls.KOBO_MOUNT_PATH:
                errors.append("KOBO_MOUNT_PATH is not set (required for USB delivery)")
        else:
            errors.append(f"Unknown DELIVERY_METHOD '{cls.DELIVERY_METHOD}'. Use: email | dropbox | usb")
        return errors
