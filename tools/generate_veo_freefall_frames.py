#!/usr/bin/env python3
import getpass
import json
import os
import subprocess
import sys
import time
from pathlib import Path


MODEL = os.environ.get("GEMINI_VEO_MODEL", "veo-3.1-generate-preview")
TMP_GENAI_SDK = Path("/private/tmp/google-genai")


def extract_frames(video_path, output_dir):
    output_dir.mkdir(parents=True, exist_ok=True)
    for existing in output_dir.glob("nori_freefall_veo_*.png"):
        existing.unlink()

    pattern = output_dir / "nori_freefall_veo_%02d.png"
    command = [
        "ffmpeg",
        "-y",
        "-i",
        str(video_path),
        "-vf",
        "select='eq(n\\,0)+eq(n\\,38)+eq(n\\,76)+eq(n\\,114)+eq(n\\,152)+eq(n\\,190)'",
        "-vsync",
        "0",
        str(pattern),
    ]
    subprocess.run(command, check=True)


def main():
    if TMP_GENAI_SDK.exists():
        sys.path.insert(0, str(TMP_GENAI_SDK))

    from google import genai
    from google.genai import types

    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        if sys.stdin.isatty():
            api_key = getpass.getpass("Gemini API key: ").strip()
        else:
            api_key = sys.stdin.readline().strip()
    if not api_key:
        raise SystemExit("GEMINI_API_KEY is required via env or stdin.")

    image_path = Path("assets/images/sprites/video_references/nori_freefall_720x1280_chromakey.png")
    video_path = Path("generated-videos/nori_freefall_veo.mp4")
    status_path = Path("generated-videos/nori_freefall_veo_operation.json")
    frames_dir = Path("assets/images/sprites/generated/nori_freefall_veo_frames")

    prompt = (
        "Create a 9:16 vertical 2D game sprite animation from this exact character reference. "
        "The character is falling downward in freefall, full body visible, centered, preserving the same identity, "
        "outfit, proportions, color palette, and cartoon sprite style. Animate subtle continuous freefall motion: "
        "arms and legs reacting to air resistance, body bobbing downward, hair and clothing fluttering. "
        "Use a perfectly flat solid chroma key green background only, no scenery, no shadows, no camera zoom, "
        "no cuts, no extra objects, no text. The motion should be readable when sampled into six sprite frames."
    )

    video_path.parent.mkdir(parents=True, exist_ok=True)
    client = genai.Client(api_key=api_key)
    image = types.Image.from_file(location=str(image_path), mime_type="image/png")
    operation = client.models.generate_videos(
        model=MODEL,
        prompt=prompt,
        image=image,
        config=types.GenerateVideosConfig(
            aspect_ratio="9:16",
            resolution="720p",
            number_of_videos=1,
        ),
    )
    status_path.write_text(operation.model_dump_json(indent=2), encoding="utf-8")

    for _ in range(90):
        operation = client.operations.get(operation)
        status_path.write_text(operation.model_dump_json(indent=2), encoding="utf-8")
        if operation.done:
            if operation.error:
                raise RuntimeError(operation.error.model_dump_json(indent=2))
            video = operation.response.generated_videos[0]
            client.files.download(file=video.video)
            video.video.save(str(video_path))
            extract_frames(video_path, frames_dir)
            print(json.dumps({
                "video": str(video_path),
                "frames_dir": str(frames_dir),
                "status": str(status_path),
            }, indent=2))
            return
        time.sleep(10)

    raise TimeoutError(f"Timed out waiting for operation {operation.name}")


if __name__ == "__main__":
    main()
