import subprocess
import shutil
import sys
from datetime import date
from pathlib import Path

from config import Config


# Calibre's built-in recipe name for The Economist (subscription edition)
ECONOMIST_RECIPE = "The Economist"


class DownloadError(Exception):
    pass


def _calibre_available() -> bool:
    binary = Config.ebook_convert()
    if shutil.which(binary):
        return True
    # Try common install locations
    for candidate in ("/opt/calibre/ebook-convert", "/usr/bin/ebook-convert"):
        if Path(candidate).exists():
            return True
    return False


def download_latest(output_dir: Path | None = None) -> Path:
    """
    Download the latest Economist edition as EPUB using Calibre's recipe.

    Requires Calibre to be installed: https://calibre-ebook.com/download
    Returns the path to the downloaded EPUB file.
    """
    if not _calibre_available():
        raise DownloadError(
            "Calibre is not installed or not on PATH.\n"
            "Install it from https://calibre-ebook.com/download\n"
            "Then re-run this script."
        )

    dest_dir = output_dir or Config.DOWNLOAD_DIR
    dest_dir.mkdir(parents=True, exist_ok=True)

    filename = f"the_economist_{date.today().isoformat()}.epub"
    output_path = dest_dir / filename

    if output_path.exists():
        print(f"[download] Already downloaded: {output_path}")
        return output_path

    cmd = [
        Config.ebook_convert(),
        ECONOMIST_RECIPE,
        str(output_path),
        "--username", Config.ECONOMIST_EMAIL,
        "--password", Config.ECONOMIST_PASSWORD,
        "--output-profile", "kobo",  # optimises layout for Kobo screens
        "--dont-download-recipe",  # use cached recipe meta, fetch live articles
    ]

    print(f"[download] Fetching latest Economist via Calibre recipe…")
    print(f"[download] Output: {output_path}")

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=600,  # recipes can take a few minutes
        )
    except subprocess.TimeoutExpired:
        raise DownloadError("Calibre download timed out after 10 minutes.")
    except FileNotFoundError:
        raise DownloadError(
            f"Could not find '{Config.ebook_convert()}'. "
            "Make sure Calibre is installed and on your PATH."
        )

    if result.returncode != 0:
        # Strip the password from the error output before printing
        stderr = result.stderr.replace(Config.ECONOMIST_PASSWORD, "***")
        raise DownloadError(
            f"Calibre exited with code {result.returncode}.\n"
            f"Stderr:\n{stderr}\n"
            f"Stdout:\n{result.stdout}"
        )

    if not output_path.exists():
        raise DownloadError(
            f"Calibre reported success but the output file was not created: {output_path}"
        )

    size_kb = output_path.stat().st_size // 1024
    print(f"[download] Done — {size_kb} KB saved to {output_path}")
    return output_path
