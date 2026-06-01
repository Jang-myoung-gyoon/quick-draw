#!/usr/bin/env python3
from pathlib import Path

from PIL import Image


INPUT_DIR = Path("assets/images/sprites/generated/nori_freefall_veo_frames")
OUTPUT_DIR = Path("assets/images/sprites/generated/nori_freefall_veo_frames_transparent")


def sample_key_color(image):
    rgb = image.convert("RGB")
    width, height = rgb.size
    points = [
        (0, 0),
        (width - 1, 0),
        (0, height - 1),
        (width - 1, height - 1),
        (width // 2, 0),
        (width // 2, height - 1),
    ]
    channels = list(zip(*(rgb.getpixel(point) for point in points)))
    return tuple(sorted(channel)[len(channel) // 2] for channel in channels)


def key_to_alpha(distance, soft_start=38, soft_end=118):
    if distance <= soft_start:
        return 0
    if distance >= soft_end:
        return 255
    return int(255 * ((distance - soft_start) / (soft_end - soft_start)))


def remove_chromakey(input_path, output_path):
    image = Image.open(input_path).convert("RGBA")
    key = sample_key_color(image)
    pixels = image.load()
    width, height = image.size

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            distance = ((r - key[0]) ** 2 + (g - key[1]) ** 2 + (b - key[2]) ** 2) ** 0.5
            alpha = min(a, key_to_alpha(distance))
            if alpha < 255:
                # Despill green edges toward neutral gray while keeping the sprite color readable.
                g = min(g, max(r, b) + 12)
            pixels[x, y] = (r, g, b, alpha)

    image.save(output_path)


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for source in sorted(INPUT_DIR.glob("*.png")):
        target = OUTPUT_DIR / source.name
        remove_chromakey(source, target)
        print(target)


if __name__ == "__main__":
    main()
