# AGENTS.md

This file configures AI coding agents working in this Flutter project.
It adapts the official Flutter and Dart AI rules for this repository.

## Project Context

- This is a Flutter app using Flame for game runtime code.
- The primary entry point is `lib/main.dart`.
- Reusable game components live under `lib/components/`.
- Tests live under `test/`.
- The project uses `flutter_lints` through `analysis_options.yaml`.

## Core Behavior

- Follow official Flutter, Dart, and Effective Dart guidance.
- Prefer small, focused changes that preserve current gameplay behavior.
- Read the existing code before changing structure or naming.
- Do not add dependencies unless the task clearly requires them or the user
  explicitly asks for them.
- When a dependency is needed, prefer stable packages from `pub.dev` and explain
  why the package is appropriate.
- Keep generated or mechanical changes out of unrelated files.

## Dart Style

- Use sound null safety. Avoid `!` unless non-nullness is guaranteed locally.
- Prefer immutable data and `final` fields where practical.
- Use `PascalCase` for types, `camelCase` for members and functions, and
  `snake_case.dart` for file names.
- Keep functions short and single-purpose.
- Prefer clear, direct code over clever code.
- Use arrow syntax only for simple one-line members.
- Use exhaustive `switch` statements or switch expressions where they simplify
  branching.
- Add comments only for non-obvious intent, constraints, or algorithms.
- Public APIs should have concise `///` dartdoc comments when they are intended
  for reuse outside their defining file.

## Flutter Rules

- Build UI by composing small widgets instead of growing large `build()` methods.
- Prefer private widget classes over private helper methods that return widgets
  when UI fragments become non-trivial.
- Use `const` constructors and `const` widget instances wherever possible.
- Do not perform expensive work, asset loading, network calls, or gameplay
  setup directly inside `build()`.
- Keep transient widget state local. For app-wide state, use simple built-in
  Flutter patterns first (`ValueNotifier`, `ChangeNotifier`, `FutureBuilder`,
  `StreamBuilder`) before introducing third-party state management.
- Centralize shared visual styling in `ThemeData` or explicit constants rather
  than scattering repeated magic values.
- Ensure layouts are responsive and overflow-safe. Use `Expanded`, `Flexible`,
  `Wrap`, `LayoutBuilder`, `ListView.builder`, or `GridView.builder` where they
  match the layout problem.
- Network images, if introduced, must include loading and error handling.
- Declare local assets in `pubspec.yaml` before referencing them.

## Flame Game Rules

- Keep game-loop logic inside Flame components or `FlameGame` methods.
- Keep Flutter overlays focused on UI presentation and input controls.
- Do not mutate Flame child collections while iterating unless the existing
  pattern is known to be safe.
- Prefer component-level responsibilities: player behavior belongs in player
  components, target behavior in target components, effects in effect
  components, and background behavior in background components.
- Keep frame-update work lightweight. Avoid allocations or expensive
  calculations inside high-frequency update paths when a cached value or
  component field is clearer.
- Preserve deterministic gameplay behavior unless the task is explicitly about
  balancing, randomness, or feel.

## Architecture

- Maintain separation between presentation, gameplay state, component behavior,
  effects, and reusable utilities.
- For larger features, organize by feature or component responsibility rather
  than adding all logic to `main.dart`.
- Prefer constructor injection for dependencies when adding testable services or
  controllers.
- Avoid introducing broad abstractions until duplication or complexity makes the
  boundary useful.

## Error Handling And Logging

- Handle expected failure paths explicitly.
- Do not silently swallow errors.
- Prefer `dart:developer` logging for structured runtime diagnostics.
- Avoid `print` in production code unless it is already accepted by the local
  lint configuration for a temporary debugging task.

## Testing

- Use Arrange-Act-Assert or Given-When-Then structure.
- Add unit tests for pure game logic, data transformations, and state behavior.
- Add widget tests for Flutter UI and overlays.
- Add integration tests only when the behavior crosses enough app surface to
  justify the cost.
- Prefer fakes or stubs over mocks. Avoid code generation for mocks unless the
  project already uses it.
- When modifying behavior, add or update tests that would fail without the
  change when practical.

## Verification

Before claiming work is complete, run the relevant checks:

```sh
dart format .
flutter analyze
flutter test
```

If a change is narrower, run the smallest equivalent command that proves it.
If verification cannot be run, report exactly what was not run and why.

## Package And Code Generation

- Use `flutter pub add <package>` for dependencies when adding packages.
- Use `flutter pub add dev:<package>` for development dependencies.
- Use `dart pub remove <package>` or `flutter pub remove <package>` when removing
  dependencies.
- If build-runner based code generation is introduced or already used, run:

```sh
dart run build_runner build --delete-conflicting-outputs
```

## Accessibility And UX

- Keep text legible under dynamic text scaling.
- Use sufficient color contrast for UI text and important controls.
- Add semantic labels for controls or game overlays when they are meaningful to
  assistive technologies.
- Avoid UI overlap on small screens.
- Prefer icons and controls that communicate game state or actions clearly.

## Source Guidance

These rules are adapted from Flutter's official AI rules documentation:

- https://docs.flutter.dev/ai/ai-rules
- https://raw.githubusercontent.com/flutter/flutter/refs/heads/main/docs/rules/rules.md
