# Source Asset Rules

- This directory is outside the Flutter asset bundle.
- Store original images, generated attempts, chromakey references, source videos, and other non-runtime material here.
- Do not reference files from this directory in runtime code.
- When creating optimized runtime assets, write them under `assets/images/` and declare only those files in `pubspec.yaml`.
