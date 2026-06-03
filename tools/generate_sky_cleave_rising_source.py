from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


OUT = Path(
    "source-assets/original-images/generated-videos/"
    "sky_cleave_rising_slash_source.png"
)
W, H = 720, 1280
SCALE = 3
KEY = (0, 255, 0, 255)


def curve_point(t: float) -> tuple[float, float]:
    # Bottom-center to upper-right, shaped like the current home art's rising trail.
    y = H * (0.91 - 0.73 * t)
    x = W * (0.47 + 0.10 * math.sin((t - 0.16) * math.pi * 1.38))
    x += W * 0.16 * (t**1.72)
    x -= W * 0.10 * ((1 - t) ** 2.35)
    return x * SCALE, y * SCALE


def tangent_at(t: float) -> tuple[float, float]:
    a = curve_point(max(0.0, t - 0.015))
    b = curve_point(min(1.0, t + 0.015))
    dx, dy = b[0] - a[0], b[1] - a[1]
    length = math.hypot(dx, dy) or 1
    return dx / length, dy / length


def draw_curve(
    layer: Image.Image,
    color: tuple[int, int, int, int],
    width: int,
    *,
    start: float = 0.0,
    end: float = 1.0,
    samples: int = 120,
) -> None:
    draw = ImageDraw.Draw(layer, "RGBA")
    pts = [
        curve_point(start + (end - start) * i / (samples - 1))
        for i in range(samples)
    ]
    draw.line(pts, fill=color, width=width * SCALE, joint="curve")


def draw_tapered_blade(layer: Image.Image) -> None:
    draw = ImageDraw.Draw(layer, "RGBA")
    left: list[tuple[float, float]] = []
    right: list[tuple[float, float]] = []
    for i in range(120):
        t = i / 119
        x, y = curve_point(t)
        tx, ty = tangent_at(t)
        nx, ny = -ty, tx
        width = (32 + 34 * math.sin(math.pi * t)) * SCALE
        if t < 0.13:
            width *= t / 0.13
        if t > 0.86:
            width *= (1 - t) / 0.14
        left.append((x + nx * width, y + ny * width))
        right.append((x - nx * width * 0.62, y - ny * width * 0.62))
    draw.polygon(left + right[::-1], fill=(255, 246, 198, 245))

    inner_left: list[tuple[float, float]] = []
    inner_right: list[tuple[float, float]] = []
    for i in range(120):
        t = i / 119
        x, y = curve_point(t)
        tx, ty = tangent_at(t)
        nx, ny = -ty, tx
        width = (12 + 18 * math.sin(math.pi * t)) * SCALE
        if t < 0.1:
            width *= t / 0.1
        if t > 0.9:
            width *= (1 - t) / 0.1
        inner_left.append((x + nx * width, y + ny * width))
        inner_right.append((x - nx * width, y - ny * width))
    draw.polygon(inner_left + inner_right[::-1], fill=(255, 255, 255, 255))


def tint_alpha(
    image: Image.Image,
    color: tuple[int, int, int],
    *,
    min_alpha: int = 1,
) -> None:
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            _, _, _, a = pixels[x, y]
            if a >= min_alpha:
                pixels[x, y] = (color[0], color[1], color[2], a)


def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    effect = Image.new("RGBA", (W * SCALE, H * SCALE), (0, 0, 0, 0))

    glow = Image.new("RGBA", effect.size, (0, 0, 0, 0))
    draw_curve(glow, (255, 177, 64, 118), 36, start=0.03, end=0.70)
    draw_curve(glow, (255, 85, 78, 78), 20, start=0.08, end=0.66)
    draw_curve(glow, (33, 196, 190, 60), 12, start=0.18, end=0.62)
    glow = glow.filter(ImageFilter.GaussianBlur(8 * SCALE))
    tint_alpha(glow, (255, 176, 68), min_alpha=2)
    effect.alpha_composite(glow)

    ribbon = Image.new("RGBA", effect.size, (0, 0, 0, 0))
    draw_curve(ribbon, (255, 181, 65, 220), 28, start=0.02, end=0.72)
    draw_curve(ribbon, (255, 112, 82, 170), 16, start=0.08, end=0.68)
    draw_curve(ribbon, (42, 178, 184, 136), 10, start=0.18, end=0.64)
    draw_tapered_blade(ribbon)

    draw = ImageDraw.Draw(ribbon, "RGBA")
    # Bottom impact bloom, matching the game's warm sky trail energy.
    bx, by = curve_point(0.0)
    for radius, color in (
        (82, (255, 146, 67, 54)),
        (58, (255, 205, 91, 120)),
        (31, (255, 255, 218, 230)),
    ):
        r = radius * SCALE
        draw.ellipse((bx - r, by - r, bx + r, by + r), fill=color)

    # Blade tip sparkle.
    tx, ty = curve_point(1.0)
    tangent = tangent_at(1.0)
    tip = (tx + tangent[0] * 74 * SCALE, ty + tangent[1] * 74 * SCALE)
    for angle in (0, math.pi / 2, math.pi / 4, -math.pi / 4):
        dx, dy = math.cos(angle) * 28 * SCALE, math.sin(angle) * 28 * SCALE
        draw.line(
            (tip[0] - dx, tip[1] - dy, tip[0] + dx, tip[1] + dy),
            fill=(255, 255, 230, 245),
            width=4 * SCALE,
        )

    # Paper motes and coral sparks along the upward cut.
    for i in range(56):
        t = 0.06 + 0.9 * ((i * 0.61803398875) % 1)
        x, y = curve_point(t)
        tx, ty = tangent_at(t)
        nx, ny = -ty, tx
        side = -1 if i % 2 else 1
        spread = (22 + (i % 9) * 11) * SCALE * side
        drift = math.sin(i * 2.23) * 34 * SCALE
        px = x + nx * spread + tx * drift
        py = y + ny * spread + ty * drift
        r = (2.3 + (i % 4) * 1.3) * SCALE
        color = (255, 206, 92, 236) if i % 3 else (255, 103, 77, 224)
        draw.rounded_rectangle(
            (px - r * 1.6, py - r, px + r * 1.6, py + r),
            radius=int(r),
            fill=color,
        )

    # Soft afterimage strokes, slightly offset from the main path.
    for offset, alpha in ((-26, 92), (31, 68), (-48, 42)):
        trail = Image.new("RGBA", effect.size, (0, 0, 0, 0))
        draw_curve(trail, (255, 226, 146, alpha), 12, start=0.03, end=0.82)
        effect.alpha_composite(trail, (offset * SCALE, int(offset * 0.35 * SCALE)))

    effect.alpha_composite(ribbon)
    effect = effect.resize((W, H), Image.Resampling.LANCZOS)

    # Flatten onto chroma key without alpha-blending colored glow into green.
    base = Image.new("RGBA", (W, H), KEY)
    source = effect.load()
    dest = base.load()
    for y in range(H):
        for x in range(W):
            r, g, b, a = source[x, y]
            if a <= 72:
                continue
            if r + g + b < 96:
                dest[x, y] = (255, 176, 68, 255)
            else:
                dest[x, y] = (r, g, b, 255)
    base.save(OUT)


if __name__ == "__main__":
    main()
