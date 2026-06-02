# Image Asset Rules

- Keep only runtime images that are referenced by code or explicitly listed in `pubspec.yaml`.
- Do not store source prompts, chromakey references, unused variants, raw video frames, or large originals here.
- Move non-runtime images to `source-assets/original-images/` with their closest matching category.
- Prefer file-level entries in `pubspec.yaml`; avoid broad directory entries that bundle stray files.
- Use lowercase snake_case names that describe role and state, not generation history.
