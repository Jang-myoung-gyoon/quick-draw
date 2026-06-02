#!/usr/bin/env python3
"""Generate a Vertex AI Veo video and extract transparent sprite frames.

This tool intentionally uses Vertex AI project/location authentication instead
of an AI Studio API key so GCP trial credits can be applied to generation.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path


DEFAULT_MODEL = os.environ.get("GEMINI_VEO_MODEL", "veo-3.1-generate-preview")
DEFAULT_PROJECT = (
    os.environ.get("VERTEX_AI_PROJECT")
    or os.environ.get("GOOGLE_CLOUD_PROJECT")
    or os.environ.get("GCLOUD_PROJECT")
    or "project-56bcbbc3-4cc7-4465-88e"
)
DEFAULT_LOCATION = (
    os.environ.get("VERTEX_AI_LOCATION")
    or os.environ.get("GOOGLE_CLOUD_LOCATION")
    or "us-central1"
)
DEFAULT_PROMPT = (
    "Create a 9:16 vertical 2D game sprite animation from this exact character "
    "reference. The character is falling downward in freefall, full body visible, "
    "centered, preserving the same identity, outfit, proportions, color palette, "
    "and cartoon sprite style. Animate subtle continuous freefall motion: arms "
    "and legs reacting to air resistance, body bobbing downward, hair and "
    "clothing fluttering. Use a perfectly flat solid chroma key green background "
    "only, no scenery, no shadows, no camera zoom, no cuts, no extra objects, "
    "no text. The motion should be readable when sampled into sprite frames."
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Generate a Veo video on Vertex AI, sample evenly spaced PNG frames, "
            "and optionally remove the chroma key background."
        )
    )
    parser.add_argument("--project", default=DEFAULT_PROJECT)
    parser.add_argument("--location", default=DEFAULT_LOCATION)
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument(
        "--input-image",
        type=Path,
        default=Path(
            "source-assets/original-images/sprites/video_references/"
            "nori_freefall_720x1280_chromakey.png"
        ),
        help="Local PNG reference image. Ignored when --input-gcs-uri is set.",
    )
    parser.add_argument(
        "--input-gcs-uri",
        help="Optional gs:// image URI. Useful when the SDK rejects local input.",
    )
    parser.add_argument("--input-mime-type", default="image/png")
    parser.add_argument(
        "--prompt",
        default=DEFAULT_PROMPT,
        help="Prompt for the video model. Use @file.txt to read from a file.",
    )
    parser.add_argument("--aspect-ratio", default="9:16")
    parser.add_argument("--resolution", default="720p")
    parser.add_argument("--duration-seconds", type=float, default=8.0)
    parser.add_argument("--frame-count", type=int, default=32)
    parser.add_argument(
        "--video-out",
        type=Path,
        default=Path("source-assets/original-images/generated-videos/nori_freefall_veo.mp4"),
    )
    parser.add_argument(
        "--status-out",
        type=Path,
        default=Path(
            "source-assets/original-images/generated-videos/"
            "nori_freefall_veo_operation.json"
        ),
    )
    parser.add_argument(
        "--frames-dir",
        type=Path,
        default=Path("source-assets/original-images/sprites/generated/nori_freefall_veo_frames"),
    )
    parser.add_argument(
        "--transparent-dir",
        type=Path,
        default=Path(
            "source-assets/original-images/sprites/generated/"
            "nori_freefall_veo_frames_transparent"
        ),
    )
    parser.add_argument("--frame-prefix", default="nori_freefall_veo")
    parser.add_argument("--output-gcs-uri", help="Optional Vertex AI output gs:// URI.")
    parser.add_argument("--poll-seconds", type=float, default=10.0)
    parser.add_argument("--timeout-seconds", type=float, default=1800.0)
    parser.add_argument(
        "--skip-generate",
        action="store_true",
        help="Skip Vertex AI generation and extract frames from --video-out.",
    )
    parser.add_argument("--skip-transparent", action="store_true")
    parser.add_argument("--key-soft-start", type=float, default=38.0)
    parser.add_argument("--key-soft-end", type=float, default=118.0)
    return parser.parse_args()


def load_prompt(value: str) -> str:
    if value.startswith("@"):
        return Path(value[1:]).read_text(encoding="utf-8").strip()
    return value


def import_genai():
    try:
        from google import genai
        from google.genai import types
    except ImportError as exc:
        raise SystemExit(
            "google-genai is required for Vertex AI Veo generation. "
            "Install it with: python3 -m pip install google-genai"
        ) from exc
    return genai, types


def build_image(types, args: argparse.Namespace):
    if args.input_gcs_uri:
        return types.Image(gcs_uri=args.input_gcs_uri, mime_type=args.input_mime_type)
    if not args.input_image.exists():
        raise FileNotFoundError(args.input_image)
    return types.Image.from_file(
        location=str(args.input_image),
        mime_type=args.input_mime_type,
    )


def build_config(types, args: argparse.Namespace):
    kwargs = {
        "aspect_ratio": args.aspect_ratio,
        "resolution": args.resolution,
        "number_of_videos": 1,
    }
    if args.duration_seconds > 0:
        kwargs["duration_seconds"] = int(round(args.duration_seconds))
    if args.output_gcs_uri:
        kwargs["output_gcs_uri"] = args.output_gcs_uri
    try:
        return types.GenerateVideosConfig(**kwargs)
    except TypeError:
        # Older google-genai versions may not expose every Vertex Veo field yet.
        kwargs.pop("duration_seconds", None)
        return types.GenerateVideosConfig(**kwargs)


def write_operation(status_path: Path, operation) -> None:
    status_path.parent.mkdir(parents=True, exist_ok=True)
    if hasattr(operation, "model_dump_json"):
        status_path.write_text(operation.model_dump_json(indent=2), encoding="utf-8")
        return
    status_path.write_text(json.dumps(str(operation), indent=2), encoding="utf-8")


def download_gcs_uri(uri: str, output_path: Path) -> bool:
    if not uri.startswith("gs://"):
        return False
    output_path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["gcloud", "storage", "cp", uri, str(output_path)], check=True)
    return True


def save_generated_video(client, generated_video, output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    video = generated_video.video
    video_bytes = getattr(video, "video_bytes", None)
    if video_bytes:
        output_path.write_bytes(video_bytes)
        return

    uri = getattr(video, "uri", None) or getattr(video, "gcs_uri", None)
    if uri and download_gcs_uri(uri, output_path):
        return

    # AI Studio-style file handles and some SDK builds expose download/save.
    client.files.download(file=video)
    video.save(str(output_path))


def generate_video(args: argparse.Namespace) -> dict[str, str]:
    genai, types = import_genai()
    client = genai.Client(
        vertexai=True,
        project=args.project,
        location=args.location,
    )
    operation = client.models.generate_videos(
        model=args.model,
        prompt=load_prompt(args.prompt),
        image=build_image(types, args),
        config=build_config(types, args),
    )
    write_operation(args.status_out, operation)

    deadline = time.monotonic() + args.timeout_seconds
    while time.monotonic() < deadline:
        operation = client.operations.get(operation)
        write_operation(args.status_out, operation)
        if operation.done:
            if getattr(operation, "error", None):
                raise RuntimeError(operation.error.model_dump_json(indent=2))
            generated_video = operation.response.generated_videos[0]
            save_generated_video(client, generated_video, args.video_out)
            return {
                "video": str(args.video_out),
                "status": str(args.status_out),
                "project": args.project,
                "location": args.location,
                "model": args.model,
            }
        time.sleep(args.poll_seconds)

    raise TimeoutError(f"Timed out waiting for Vertex AI operation: {operation.name}")


def extract_frames(
    video_path: Path,
    output_dir: Path,
    prefix: str,
    count: int,
    duration: float,
) -> None:
    if count <= 0:
        raise ValueError("--frame-count must be greater than 0")
    if duration <= 0:
        raise ValueError("--duration-seconds must be greater than 0")

    output_dir.mkdir(parents=True, exist_ok=True)
    for existing in output_dir.glob(f"{prefix}_*.png"):
        existing.unlink()

    fps = count / duration
    pattern = output_dir / f"{prefix}_%03d.png"
    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-i",
            str(video_path),
            "-vf",
            f"fps={fps:.8f}",
            "-frames:v",
            str(count),
            "-start_number",
            "1",
            str(pattern),
        ],
        check=True,
    )


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


def key_to_alpha(distance: float, soft_start: float, soft_end: float) -> int:
    if distance <= soft_start:
        return 0
    if distance >= soft_end:
        return 255
    return int(255 * ((distance - soft_start) / (soft_end - soft_start)))


def remove_chromakey(
    input_path: Path,
    output_path: Path,
    soft_start: float,
    soft_end: float,
) -> None:
    try:
        from PIL import Image
    except ImportError as exc:
        raise SystemExit(
            "Pillow is required for transparent frame extraction. "
            "Install it with: python3 -m pip install pillow"
        ) from exc

    image = Image.open(input_path).convert("RGBA")
    key = sample_key_color(image)
    pixels = image.load()
    width, height = image.size

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            distance = ((r - key[0]) ** 2 + (g - key[1]) ** 2 + (b - key[2]) ** 2) ** 0.5
            alpha = min(a, key_to_alpha(distance, soft_start, soft_end))
            if alpha < 255:
                g = min(g, max(r, b) + 12)
            pixels[x, y] = (r, g, b, alpha)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    image.save(output_path)


def make_transparent_frames(args: argparse.Namespace) -> None:
    args.transparent_dir.mkdir(parents=True, exist_ok=True)
    for source in sorted(args.frames_dir.glob(f"{args.frame_prefix}_*.png")):
        remove_chromakey(
            source,
            args.transparent_dir / source.name,
            args.key_soft_start,
            args.key_soft_end,
        )


def main() -> None:
    args = parse_args()
    if args.skip_generate:
        if not args.video_out.exists():
            raise FileNotFoundError(args.video_out)
        result = {"video": str(args.video_out), "status": "generation skipped"}
    else:
        result = generate_video(args)
    extract_frames(
        args.video_out,
        args.frames_dir,
        args.frame_prefix,
        args.frame_count,
        args.duration_seconds,
    )
    result["frames_dir"] = str(args.frames_dir)
    if not args.skip_transparent:
        make_transparent_frames(args)
        result["transparent_dir"] = str(args.transparent_dir)
    print(json.dumps(result, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
