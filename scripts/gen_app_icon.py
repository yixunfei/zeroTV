"""Generate the zeroTV app icon set (Android PNGs + Windows .ico).

Draws a rounded-square "TV screen with play triangle" mark. Re-run after
changing the design; outputs are committed to the repo.

Usage:  python scripts/gen_app_icon.py
"""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

# Brand palette (dark-friendly, no broadcaster logos involved).
_BG = (17, 24, 39, 255)            # deep navy
_BG_GRAD_END = (31, 58, 106, 255)  # navy-blue gradient end
_ACCENT = (56, 189, 248, 255)      # cyan accent
_PLAY = (239, 246, 255, 255)       # near-white play triangle

_REPO_ROOT = Path(__file__).resolve().parent.parent
_ANDROID_RES = _REPO_ROOT / "apps" / "player" / "android" / "app" / "src" / "main" / "res"
_WINDOWS_RES = _REPO_ROOT / "apps" / "player" / "windows" / "runner" / "resources"

# Android launcher icon sizes (adaptive-icon foreground payload keeps ~66%
# of the canvas inside the safe zone; we draw full-bleed legacy icons).
_ANDROID_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}
_ICO_SIZES = [16, 24, 32, 48, 64, 128, 256]


def _lerp(a: int, b: int, t: float) -> int:
    return round(a + (b - a) * t)


def _gradient_bg(size: int) -> Image.Image:
    """Vertical gradient background (navy -> blue)."""
    img = Image.new("RGBA", (size, size), _BG)
    px = img.load()
    for y in range(size):
        t = y / max(size - 1, 1)
        color = (
            _lerp(_BG[0], _BG_GRAD_END[0], t),
            _lerp(_BG[1], _BG_GRAD_END[1], t),
            _lerp(_BG[2], _BG_GRAD_END[2], t),
            255,
        )
        for x in range(size):
            px[x, y] = color
    return img


def _rounded_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def draw_icon(size: int, *, legacy: bool = True) -> Image.Image:
    """Draw the zeroTV mark at `size` px.

    legacy=True renders the full-bleed rounded square used for the classic
    launcher icon and the Windows ico.
    """
    scale = size / 1024.0
    bg = _gradient_bg(size)
    radius = round(180 * scale) if legacy else 0

    overlay = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)

    s = scale  # shorthand

    # TV antenna (two legs + crossbar) above the screen.
    cx = size / 2
    antenna_top_y = 150 * s
    antenna_base_y = 250 * s
    leg_dx = 120 * s
    leg_w = max(round(28 * s), 2)
    d.line(
        (cx - leg_dx, antenna_top_y, cx - leg_dx * 0.35, antenna_base_y),
        fill=_ACCENT,
        width=leg_w,
    )
    d.line(
        (cx + leg_dx, antenna_top_y, cx + leg_dx * 0.35, antenna_base_y),
        fill=_ACCENT,
        width=leg_w,
    )
    d.ellipse(
        (
            cx - leg_dx - leg_w / 2,
            antenna_top_y - leg_w / 2,
            cx - leg_dx + leg_w / 2,
            antenna_top_y + leg_w / 2,
        ),
        fill=_ACCENT,
    )
    d.ellipse(
        (
            cx + leg_dx - leg_w / 2,
            antenna_top_y - leg_w / 2,
            cx + leg_dx + leg_w / 2,
            antenna_top_y + leg_w / 2,
        ),
        fill=_ACCENT,
    )

    # TV body.
    body_left, body_top = 130 * s, 265 * s
    body_right, body_bottom = (1024 - 130) * s, (1024 - 100) * s
    body_radius = 110 * s
    outline_w = max(round(56 * s), 2)
    d.rounded_rectangle(
        (body_left, body_top, body_right, body_bottom),
        radius=body_radius,
        outline=_ACCENT,
        width=outline_w,
    )

    # Play triangle centered in the TV body.
    bx = (body_left + body_right) / 2
    by = (body_top + body_bottom) / 2
    tri_h = 300 * s
    tri_w = 260 * s
    apex = (bx + tri_w / 2, by)
    top = (bx - tri_w / 2, by - tri_h / 2)
    bottom = (bx - tri_w / 2, by + tri_h / 2)
    d.polygon((top, apex, bottom), fill=_PLAY)

    # Signal arcs on the right side of the screen.
    arc_cx = body_right - 40 * s
    arc_cy = body_top + 90 * s
    arc_w = max(round(26 * s), 2)
    for i, r in enumerate((55, 95, 135)):
        rr = r * s
        alpha = 255 - i * 70
        bbox = (
            arc_cx - rr,
            arc_cy - rr,
            arc_cx + rr,
            arc_cy + rr,
        )
        arc_color = (*_ACCENT[:3], alpha)
        d.arc(bbox, start=250, end=330, fill=arc_color, width=arc_w)

    if legacy and radius > 0:
        mask = _rounded_mask(size, radius)
        out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        out.paste(bg, (0, 0), mask)
        out.alpha_composite(overlay)
        return out

    out = bg.copy()
    out.alpha_composite(overlay)
    return out


def main() -> None:
    for folder, size in _ANDROID_SIZES.items():
        icon = draw_icon(size, legacy=True)
        target = _ANDROID_RES / folder / "ic_launcher.png"
        target.parent.mkdir(parents=True, exist_ok=True)
        icon.save(target)
        print(f"wrote {target} ({size}x{size})")

    ico_images = [draw_icon(s, legacy=True) for s in _ICO_SIZES]
    _WINDOWS_RES.mkdir(parents=True, exist_ok=True)
    ico_path = _WINDOWS_RES / "app_icon.ico"
    ico_images[-1].save(
        ico_path,
        format="ICO",
        append_images=ico_images[:-1],
    )
    print(f"wrote {ico_path} (sizes: {[s for s in _ICO_SIZES]})")

    # Preview for human review (not committed; temp dir outside repo).
    preview = draw_icon(512, legacy=True)
    preview_path = Path(__file__).resolve().parent.parent / "build" / "icon_preview.png"
    preview_path.parent.mkdir(parents=True, exist_ok=True)
    preview.save(preview_path)
    print(f"wrote {preview_path} (preview)")


if __name__ == "__main__":
    main()
