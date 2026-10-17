"""Leftovers of the removed profile photo feature, kept for older app versions."""

import shutil
from pathlib import Path

from database import utc_now

_UPLOAD_DIR = Path(__file__).resolve().parent / "uploads" / "avatars"


def photo_meta() -> dict:
    """The "no photo" answer older app versions expect."""
    # No photo, stamped now so older apps (newer server time wins) drop the
    # photo they still keep on the device and stop uploading it.
    return {"has_photo": False, "photo_updated_at": utc_now()}


def remove_uploaded_photos() -> None:
    """Free the space taken by photos uploaded before the feature was removed."""
    shutil.rmtree(_UPLOAD_DIR, ignore_errors=True)
