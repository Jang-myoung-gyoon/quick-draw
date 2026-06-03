from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


OUT = Path("source-assets/original-images/generated-videos/sky_cleave_slash_source.png")
W, H = 1536, 864
SCALE = 3
KEY = (0, 255, 0, 255)


def point_on_arc(t: float) -> tuple[float, float]:
    angle = math.radians(205 - 148 * t)
    radius_x = 560
    radius_y = 255
    cx, cy = W * 0.51, H * 0.55
    x = cx + math.cos(angle) * radius_x
    y = cy + math.sin(angle) * radius_y - math.sin(math.pi * t) * 86
    return x * SCALE, y * SCALE


def draw_polyline(
    layer: Image.Image,
    color: tuple[int, int, int, int],
    width: int,
    *,
    samples: int = 90,
) -> None:
    draw = ImageDraw.Draw(layer, "RGBA")
    pts = [point_on_arc(i / (samples - 1)) for i in range(samples)]
    draw.line(pts, fill=color, width=width * SCALE, joint="curve")


def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    base = Image.new("RGBA", (W * SCALE, H * SCALE), KEY)

    glow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw_polyline(glow, (45, 218, 214, 132), 96)
    draw_polyline(glow, (255, 116, 104, 82), 42)
    glow = glow.filter(ImageFilter.GaussianBlur(18 * SCALE))
    base.alpha_composite(glow)

    body = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw_polyline(body, (38, 198, 206, 220), 68)
    draw_polyline(body, (203, 251, 255, 255), 34)
    draw_polyline(body, (255, 255, 255, 255), 14)

    draw = ImageDraw.Draw(body, "RGBA")
    # Ink-brush tapered tips.
    for t, direction in ((0.04, -1), (0.96, 1)):
        x, y = point_on_arc(t)
        angle = math.atan2(
            point_on_arc(min(1, t + 0.02))[1] - point_on_arc(max(0, t - 0.02))[1],
            point_on_arc(min(1, t + 0.02))[0] - point_on_arc(max(0, t - 0.02))[0],
        )
        length = 150 * SCALE
        spread = 34 * SCALE
        tip = (x + math.cos(angle) * length * direction, y + math.sin(angle) * length * direction)
        normal = (-math.sin(angle), math.cos(angle))
        poly = [
            tip,
            (x + normal[0] * spread, y + normal[1] * spread),
            (x - normal[0] * spread, y - normal[1] * spread),
        ]
        draw.polygon(poly, fill=(19, 107, 126, 198))

    # Coral sparks and gold paper motes.
    for i in range(34):
        t = (i * 0.071 + 0.08) % 1.0
        if t < 0.06 or t > 0.94:
            continue
        x, y = point_on_arc(t)
        offset = math.sin(i * 12.9898) * 88 * SCALE
        x += math.cos(i * 4.71) * offset
        y += math.sin(i * 3.31) * 58 * SCALE
        r = (4 + i % 5) * SCALE
        color = (255, 122, 102, 230) if i % 3 else (255, 209, 96, 235)
        draw.rounded_rectangle((x - r, y - r * 0.55, x + r, y + r * 0.55), radius=r // 2, fill=color)

    # Directional after-image strokes.
    for shift, alpha in ((-46, 96), (-82, 58), (38, 70)):
        trail = Image.new("RGBA", base.size, (0, 0, 0, 0))
        draw_polyline(trail, (91, 229, 228, alpha), 18)
        base.alpha_composite(trail, (shift * SCALE, int(-shift * 0.18 * SCALE)))

    base.alpha_composite(body)
    base = base.resize((W, H), Image.Resampling.LANCZOS)
    base.save(OUT)


if __name__ == "__main__":
    main()
