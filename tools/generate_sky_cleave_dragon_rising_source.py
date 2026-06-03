from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


OUT = Path(
    "source-assets/original-images/generated-videos/"
    "sky_cleave_dragon_rising_source.png"
)
W, H = 720, 1280
SCALE = 3
KEY = (0, 255, 0, 255)


def body_point(t: float) -> tuple[float, float]:
    y = H * (0.93 - 0.78 * t)
    wave = math.sin(t * math.pi * 2.45 - 0.7)
    x = W * (0.49 + 0.18 * wave + 0.12 * (t - 0.5))
    return x * SCALE, y * SCALE


def tangent_at(t: float) -> tuple[float, float]:
    a = body_point(max(0.0, t - 0.012))
    b = body_point(min(1.0, t + 0.012))
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
    samples: int = 160,
) -> None:
    draw = ImageDraw.Draw(layer, "RGBA")
    pts = [
        body_point(start + (end - start) * i / (samples - 1))
        for i in range(samples)
    ]
    draw.line(pts, fill=color, width=width * SCALE, joint="curve")


def tint_alpha(image: Image.Image, color: tuple[int, int, int], min_alpha: int) -> None:
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            _, _, _, a = pixels[x, y]
            if a >= min_alpha:
                pixels[x, y] = (color[0], color[1], color[2], a)


def draw_dragon_head(layer: Image.Image) -> None:
    x, y = body_point(0.965)
    tx, ty = tangent_at(0.965)
    patch = Image.new("RGBA", (330 * SCALE, 240 * SCALE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(patch, "RGBA")
    cx, cy = 120 * SCALE, 120 * SCALE

    # Dragon head faces right in local space; rotate to the path tangent.
    draw.ellipse(
        (
            cx - 58 * SCALE,
            cy - 48 * SCALE,
            cx + 58 * SCALE,
            cy + 48 * SCALE,
        ),
        fill=(255, 236, 174, 255),
        outline=(255, 126, 61, 255),
        width=7 * SCALE,
    )
    draw.rounded_rectangle(
        (
            cx + 24 * SCALE,
            cy - 31 * SCALE,
            cx + 132 * SCALE,
            cy + 24 * SCALE,
        ),
        radius=22 * SCALE,
        fill=(255, 246, 198, 255),
        outline=(255, 126, 61, 255),
        width=7 * SCALE,
    )
    draw.polygon(
        [
            (cx + 72 * SCALE, cy + 16 * SCALE),
            (cx + 145 * SCALE, cy + 43 * SCALE),
            (cx + 56 * SCALE, cy + 48 * SCALE),
        ],
        fill=(255, 205, 94, 255),
    )
    draw.line(
        (
            cx + 52 * SCALE,
            cy + 15 * SCALE,
            cx + 132 * SCALE,
            cy + 32 * SCALE,
        ),
        fill=(255, 83, 68, 255),
        width=7 * SCALE,
    )

    for side in (-1, 1):
        horn_base = (cx - 22 * SCALE, cy + side * 30 * SCALE)
        horn_tip = (cx - 98 * SCALE, cy + side * 78 * SCALE)
        draw.line(horn_base + horn_tip, fill=(255, 222, 108, 255), width=10 * SCALE)

        whisker_base = (cx + 95 * SCALE, cy + side * 16 * SCALE)
        whisker_tip = (cx + 180 * SCALE, cy + side * 82 * SCALE)
        draw.line(whisker_base + whisker_tip, fill=(255, 218, 101, 240), width=6 * SCALE)

    eye = (cx + 42 * SCALE, cy - 20 * SCALE)
    r = 9 * SCALE
    draw.ellipse((eye[0] - r, eye[1] - r, eye[0] + r, eye[1] + r), fill=(255, 87, 70, 255))
    draw.ellipse((eye[0] - 3 * SCALE, eye[1] - 4 * SCALE, eye[0], eye[1] - SCALE), fill=(255, 255, 230, 255))

    angle = math.degrees(math.atan2(ty, tx))
    rotated = patch.rotate(angle, resample=Image.Resampling.BICUBIC, expand=True)
    px = int(x + tx * 52 * SCALE - rotated.width / 2)
    py = int(y + ty * 52 * SCALE - rotated.height / 2)
    layer.alpha_composite(rotated, (px, py))


def draw_scales_and_sparks(layer: Image.Image) -> None:
    draw = ImageDraw.Draw(layer, "RGBA")
    for i in range(44):
        t = 0.08 + i / 52
        x, y = body_point(t)
        tx, ty = tangent_at(t)
        nx, ny = -ty, tx
        side = -1 if i % 2 else 1
        scale_x = x + nx * side * (24 + (i % 5) * 5) * SCALE
        scale_y = y + ny * side * (24 + (i % 5) * 5) * SCALE
        rr = (5 + (i % 3) * 1.5) * SCALE
        draw.polygon(
            [
                (scale_x + tx * rr * 1.8, scale_y + ty * rr * 1.8),
                (scale_x - tx * rr + nx * side * rr, scale_y - ty * rr + ny * side * rr),
                (scale_x - tx * rr - nx * side * rr, scale_y - ty * rr - ny * side * rr),
            ],
            fill=(255, 223, 118, 230),
        )

    # Flame-like dorsal fins make the body read as a creature instead of a ribbon.
    for i in range(17):
        t = 0.14 + i / 22
        x, y = body_point(t)
        tx, ty = tangent_at(t)
        nx, ny = -ty, tx
        side = 1 if i % 2 == 0 else -1
        base_w = 16 * SCALE
        fin_h = (28 + (i % 4) * 7) * SCALE
        draw.polygon(
            [
                (x + tx * base_w, y + ty * base_w),
                (x - tx * base_w, y - ty * base_w),
                (x + nx * side * fin_h - tx * 6 * SCALE, y + ny * side * fin_h - ty * 6 * SCALE),
            ],
            fill=(255, 102, 73, 225),
        )

    for i in range(78):
        t = 0.03 + 0.94 * ((i * 0.61803398875) % 1)
        x, y = body_point(t)
        tx, ty = tangent_at(t)
        nx, ny = -ty, tx
        side = -1 if i % 2 else 1
        spread = (40 + (i % 10) * 12) * SCALE * side
        drift = math.sin(i * 2.17) * 42 * SCALE
        px = x + nx * spread + tx * drift
        py = y + ny * spread + ty * drift
        r = (2.2 + (i % 4) * 1.3) * SCALE
        color = (255, 202, 82, 240) if i % 3 else (255, 96, 75, 230)
        draw.rounded_rectangle(
            (px - r * 1.6, py - r, px + r * 1.6, py + r),
            radius=int(r),
            fill=color,
        )


def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    effect = Image.new("RGBA", (W * SCALE, H * SCALE), (0, 0, 0, 0))

    glow = Image.new("RGBA", effect.size, (0, 0, 0, 0))
    draw_curve(glow, (255, 176, 63, 165), 92)
    draw_curve(glow, (255, 96, 76, 110), 56, start=0.04, end=0.92)
    draw_curve(glow, (36, 202, 194, 86), 34, start=0.12, end=0.84)
    glow = glow.filter(ImageFilter.GaussianBlur(10 * SCALE))
    tint_alpha(glow, (255, 179, 66), min_alpha=2)
    effect.alpha_composite(glow)

    dragon = Image.new("RGBA", effect.size, (0, 0, 0, 0))
    draw_curve(dragon, (255, 132, 58, 248), 54, start=0.02, end=0.94)
    draw_curve(dragon, (255, 211, 96, 255), 36, start=0.04, end=0.96)
    draw_curve(dragon, (255, 255, 224, 255), 16, start=0.06, end=0.97)

    # Sword-cut core follows the dragon spine so the creature still reads as a slash.
    blade = Image.new("RGBA", effect.size, (0, 0, 0, 0))
    draw_curve(blade, (255, 255, 255, 255), 24, start=0.0, end=0.98)
    draw_curve(blade, (35, 196, 190, 205), 7, start=0.14, end=0.82)
    dragon.alpha_composite(blade)

    draw_scales_and_sparks(dragon)
    draw_dragon_head(dragon)

    draw = ImageDraw.Draw(dragon, "RGBA")
    bx, by = body_point(0.0)
    for radius, color in (
        (112, (255, 115, 67, 86)),
        (72, (255, 204, 86, 155)),
        (32, (255, 255, 218, 255)),
    ):
        r = radius * SCALE
        draw.ellipse((bx - r, by - r, bx + r, by + r), fill=color)

    effect.alpha_composite(dragon)
    effect = effect.resize((W, H), Image.Resampling.LANCZOS)

    base = Image.new("RGBA", (W, H), KEY)
    source = effect.load()
    dest = base.load()
    for y in range(H):
        for x in range(W):
            r, g, b, a = source[x, y]
            if a <= 58:
                continue
            if r + g + b < 96:
                dest[x, y] = (255, 176, 68, 255)
            else:
                dest[x, y] = (r, g, b, 255)
    base.save(OUT)


if __name__ == "__main__":
    main()
