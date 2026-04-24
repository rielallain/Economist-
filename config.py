import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()


class Config:
    # Economist subscription credentials
    ECONOMIST_EMAIL = os.getenv("ECONOMIST_EMAIL", "")
    ECONOMIST_PASSWORD = os.getenv("ECONOMIST_PASSWORD", "")

    # Delivery method: "calibredb", "email", "dropbox", or "usb"
    DELIVERY_METHOD = os.getenv("DELIVERY_METHOD", "calibredb")

    # Calibre-Web delivery (primary wireless method)
    # Path to your Calibre library folder (created by the Calibre app on first run)
    CALIBRE_LIBRARY = Path(os.getenv("CALIBRE_LIBRARY", "~/Calibre Library")).expanduser()

    # Send to Kobo via email (alternative)
    KOBO_EMAIL = os.getenv("KOBO_EMAIL", "")
    SMTP_HOST = os.getenv("SMTP_HOST", "smtp.gmail.com")
    SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
    SMTP_USER = os.getenv("SMTP_USER", "")
    SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "")

    # Dropbox delivery (alternative)
    DROPBOX_PATH = Path(os.getenv("DROPBOX_PATH", "~/Dropbox/Books")).expanduser()

    # USB / mounted Kobo path (fallback)
    KOBO_MOUNT_PATH = Path(os.getenv("KOBO_MOUNT_PATH", "")).expanduser() if os.getenv("KOBO_MOUNT_PATH") else None

    # Where to save downloaded EPUB files locally
    DOWNLOAD_DIR = Path(os.getenv("DOWNLOAD_DIR", "~/Downloads/Economist")).expanduser()

    # Optional: path to Calibre binaries (e.g. /Applications/calibre.app/Contents/MacOS)
    CALIBRE_BIN = os.getenv("CALIBRE_BIN", "")

    @classmethod
    def _bin(cls, name: str) -> str:
        if cls.CALIBRE_BIN:
            return str(Path(cls.CALIBRE_BIN) / name)
        return name

    @classmethod
    def ebook_convert(cls) -> str:
        return cls._bin("ebook-convert")

    @classmethod
    def calibredb(cls) -> str:
        return cls._bin("calibredb")

    @classmethod
    def validate(cls) -> list[str]:
        errors = []
        if not cls.ECONOMIST_EMAIL:
            errors.append("ECONOMIST_EMAIL is not set")
        if not cls.ECONOMIST_PASSWORD:
            errors.append("ECONOMIST_PASSWORD is not set")
        if cls.DELIVERY_METHOD == "calibredb":
            if not cls.CALIBRE_LIBRARY.exists():
                errors.append(
                    f"CALIBRE_LIBRARY not found at {cls.CALIBRE_LIBRARY}. "
                    "Open the Calibre app once to create it, or set CALIBRE_LIBRARY in .env"
                )
        elif cls.DELIVERY_METHOD == "email":
            for var in ("SMTP_USER", "SMTP_PASSWORD", "KOBO_EMAIL"):
                if not getattr(cls, var):
                    errors.append(f"{var} is not set (required for email delivery)")
        elif cls.DELIVERY_METHOD == "dropbox":
            pass
        elif cls.DELIVERY_METHOD == "usb":
            if not cls.KOBO_MOUNT_PATH:
                errors.append("KOBO_MOUNT_PATH is not set (required for USB delivery)")
        else:
            errors.append(
                f"Unknown DELIVERY_METHOD '{cls.DELIVERY_METHOD}'. "
                "Use: calibredb | email | dropbox | usb"
            )
        return errors
