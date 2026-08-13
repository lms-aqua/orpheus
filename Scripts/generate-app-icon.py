#!/usr/bin/env python3
"""Generate the ORPHEUS app icon.

The mark is an aperture: concentric rings whose gaps rotate, so the eye reads a
letter O made of layered apertures rather than a literal object. Deliberately
not a padlock, not an eye, not a shield -- per the brief, and because those
marks say "security product" rather than "this is mine".

    py -3.11 Scripts/generate-app-icon.py

Writes ORPHEUS/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png at
1024x1024, which is the only size the modern asset catalog needs.
"""

from __future__ import annotations

import math
import pathlib

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
SUPERSAMPLE = 4  # draw large, downsample once, for clean antialiased curves

# Graphite base with a faint vertical lift, so the icon has depth without a
# loud gradient.
BACKGROUND_TOP = (34, 36, 44)
BACKGROUND_BOTTOM = (20, 21, 27)

INDIGO = (122, 142, 255)
INDIGO_DIM = (74, 88, 176)
OFF_WHITE = (238, 239, 244)


def radial_background(size: int) -> Image.Image:
    """Vertical graphite ramp."""
    base = Image.new("RGB", (1, size))
    pixels = base.load()
    for y in range(size):
        t = y / max(size - 1, 1)
        pixels[0, y] = tuple(
            round(BACKGROUND_TOP[i] + (BACKGROUND_BOTTOM[i] - BACKGROUND_TOP[i]) * t)
            for i in range(3)
        )
    return base.resize((size, size), Image.BILINEAR)


def draw_arc_ring(
    draw: ImageDraw.ImageDraw,
    center: float,
    radius: float,
    width: float,
    start: float,
    extent: float,
    color: tuple[int, int, int],
) -> None:
    box = (center - radius, center - radius, center + radius, center + radius)
    draw.arc(box, start, start + extent, fill=color, width=round(width))


def build() -> Image.Image:
    size = SIZE * SUPERSAMPLE
    center = size / 2

    canvas = radial_background(size).convert("RGBA")

    # Soft indigo bloom behind the mark: gives the glass-era look a little
    # atmosphere without turning into a neon glow.
    bloom = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bloom_draw = ImageDraw.Draw(bloom)
    bloom_radius = size * 0.30
    bloom_draw.ellipse(
        (
            center - bloom_radius,
            center - bloom_radius,
            center + bloom_radius,
            center + bloom_radius,
        ),
        fill=(*INDIGO_DIM, 90),
    )
    bloom = bloom.filter(ImageFilter.GaussianBlur(size * 0.055))
    canvas = Image.alpha_composite(canvas, bloom)

    mark = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(mark)

    # Three apertures. Each ring leaves a gap, and the gaps advance around the
    # circle, which is what produces the sense of layered rotation.
    rings = [
        # radius factor, stroke factor, gap degrees, rotation, color
        (0.300, 0.052, 62, -108, OFF_WHITE),
        (0.213, 0.044, 74, 30, INDIGO),
        (0.128, 0.036, 88, 158, OFF_WHITE),
    ]
    for radius_f, width_f, gap, rotation, color in rings:
        draw_arc_ring(
            draw,
            center=center,
            radius=size * radius_f,
            width=size * width_f,
            start=rotation,
            extent=360 - gap,
            color=color,
        )

    # Centre dot: the focal point the apertures resolve to.
    dot = size * 0.030
    draw.ellipse(
        (center - dot, center - dot, center + dot, center + dot),
        fill=INDIGO,
    )

    canvas = Image.alpha_composite(canvas, mark)
    return canvas.convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)


def main() -> None:
    destination = (
        pathlib.Path(__file__).resolve().parents[1]
        / "ORPHEUS"
        / "Resources"
        / "Assets.xcassets"
        / "AppIcon.appiconset"
        / "AppIcon.png"
    )
    destination.parent.mkdir(parents=True, exist_ok=True)
    icon = build()
    # No alpha channel: iOS app icons must be fully opaque.
    icon.save(destination, "PNG", optimize=True)
    print(f"Wrote {destination} ({icon.size[0]}x{icon.size[1]})")


if __name__ == "__main__":
    main()
