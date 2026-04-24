#!/usr/bin/env python3
"""
economist-kobo-sync — download the latest Economist and send it to your Kobo.

Usage:
    python sync.py               # download + deliver
    python sync.py --download    # download only
    python sync.py --deliver <file.epub>   # deliver a specific file
    python sync.py --schedule    # run every Friday at 07:00

See .env.example for required configuration.
"""

import argparse
import sys
import time
from pathlib import Path

from config import Config
from downloader import download_latest, DownloadError
from deliver import deliver, DeliveryError


def run_sync() -> int:
    errors = Config.validate()
    if errors:
        print("Configuration errors:")
        for e in errors:
            print(f"  - {e}")
        print("\nCopy .env.example to .env and fill in your details.")
        return 1

    try:
        epub = download_latest()
    except DownloadError as exc:
        print(f"[error] Download failed: {exc}")
        return 1

    try:
        deliver(epub)
    except DeliveryError as exc:
        print(f"[error] Delivery failed: {exc}")
        return 1

    return 0


def run_schedule(day: str = "friday", hour: int = 7) -> None:
    """Block forever, running a sync each week on the given day."""
    try:
        import schedule
    except ImportError:
        print("Install the 'schedule' package to use --schedule: pip install schedule")
        sys.exit(1)

    def job():
        print(f"[schedule] Starting weekly sync…")
        code = run_sync()
        if code != 0:
            print("[schedule] Sync failed — will retry next week.")

    getattr(schedule.every(), day).at(f"{hour:02d}:00").do(job)
    print(f"[schedule] Economist sync scheduled every {day.capitalize()} at {hour:02d}:00.")
    print("[schedule] Running — press Ctrl+C to stop.")

    # Run immediately on first start so you don't have to wait a week
    print("[schedule] Running initial sync now…")
    job()

    while True:
        schedule.run_pending()
        time.sleep(60)


def main() -> None:
    parser = argparse.ArgumentParser(description="Sync the Economist to your Kobo")
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--download", action="store_true", help="Download only, don't deliver")
    group.add_argument("--deliver", metavar="FILE", help="Deliver an existing EPUB file")
    group.add_argument(
        "--schedule",
        action="store_true",
        help="Run automatically every Friday at 07:00 (requires 'schedule' package)",
    )
    args = parser.parse_args()

    if args.download:
        errors = Config.validate()
        if errors:
            print("Configuration errors:")
            for e in errors:
                print(f"  - {e}")
            sys.exit(1)
        try:
            epub = download_latest()
            print(f"Downloaded: {epub}")
        except DownloadError as exc:
            print(f"[error] {exc}")
            sys.exit(1)

    elif args.deliver:
        epub_path = Path(args.deliver)
        if not epub_path.exists():
            print(f"[error] File not found: {epub_path}")
            sys.exit(1)
        try:
            deliver(epub_path)
        except DeliveryError as exc:
            print(f"[error] {exc}")
            sys.exit(1)

    elif args.schedule:
        run_schedule()

    else:
        sys.exit(run_sync())


if __name__ == "__main__":
    main()
