"""Generate the zeroTV app icon set (Android PNGs + Windows .ico) from the
brand source image ``assets/brand/logo.jpg``.

The source is a near-square JPEG. For each target size we:

1. center-crop to a square,
2. resize with LANCZOS,
3. apply a rounded-corner alpha mask so the icon reads as an app tile
   (Android launchers and Windows both honor per-pixel alpha).

Re-run after replacing the source image; outputs are committed to the repo.

Usage:  python scripts/gen_app_icon.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

_REPO_ROOT = Path(__file__).resolve().parent.parent
_SOURCE = _REPO_ROOT / "assets" / "brand" / "logo.jpg"
_ANDROID_RES = (
    _REPO_ROOT / "apps" / "player" / "android" / "app" / "src" / "main" / "res"
)
_WINDOWS_RES = _REPO_ROOT / "apps" / "player" / "windows" / "runner" / "resources"
_PREVIEW_DIR = _REPO_ROOT / "build"

# Android launcher icon sizes (legacy full-bleed icons; adaptive-icon XML
# would reference the same mipmap name if added later).
_ANDROID_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}
# Windows .ico frames. 256 is the largest size Explorer will use; smaller
# frames keep the file crisp at legacy DPIs.
_ICO_SIZES = [16, 24, 32, 48, 64, 128, 256]

# Corner radius as a fraction of the canvas. ~18% matches Material You
# "squircle"-ish launcher tiles without looking round.
_RADIUS_FRACTION = 0.18


def _center_crop_square(img: Image.Image) -> Image.Image:
    """Crop the longest side centered so the result is square."""
    w, h = img.size
    side = min(w, h)
    left = (w - side) // 2
    top = (h - side) // 2
    return img.crop((left, top, left + side, top + side))


def _rounded_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def render_icon(source: Image.Image, size: int) -> Image.Image:
    """Render the brand mark at ``size`` px with rounded corners."""
    square = _center_crop_square(source)
    resized = square.resize((size, size), Image.LANCZOS).convert("RGBA")
    radius = max(round(size * _RADIUS_FRACTION), 1)
    mask = _rounded_mask(size, radius)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(resized, (0, 0), mask)
    return out


def main() -> None:
    if not _SOURCE.exists():
        raise SystemExit(f"source image not found: {_SOURCE}")
    source = Image.open(_SOURCE)

    for folder, size in _ANDROID_SIZES.items():
        icon = render_icon(source, size)
        target = _ANDROID_RES / folder / "ic_launcher.png"
        target.parent.mkdir(parents=True, exist_ok=True)
        icon.save(target)
        print(f"wrote {target} ({size}x{size})")

    ico_images = [render_icon(source, s) for s in _ICO_SIZES]
    _WINDOWS_RES.mkdir(parents=True, exist_ok=True)
    ico_path = _WINDOWS_RES / "app_icon.ico"
    ico_images[-1].save(
        ico_path,
        format="ICO",
        append_images=ico_images[:-1],
    )
    print(f"wrote {ico_path} (sizes: {list(_ICO_SIZES)})")

    # Preview for human review (build/ is gitignored).
    preview = render_icon(source, 512)
    _PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    preview_path = _PREVIEW_DIR / "icon_preview.png"
    preview.save(preview_path)
    print(f"wrote {preview_path} (preview)")


if __name__ == "__main__":
    main()
