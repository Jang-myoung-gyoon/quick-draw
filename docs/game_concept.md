# Game Concept

## Fixed Concept

**Title:** Lantern Dash

**Genre:** casual mobile 2D chain-slash action game

**Core fantasy:** The player controls Nori, a tiny battoujutsu sky courier who dashes through a floating paper-lantern sky. Players tap waypoints to draw a quick slash route, then Nori unsheathes in a flash, zipping along the path and slicing enchanted ink wisps while avoiding storm charms.

**One-line pitch:** Draw a path, dash through magical targets, and keep the lantern courier climbing.

## Gameplay Fit

- The current waypoint chain slash maps to Nori planning a mid-air battoujutsu dash.
- Blue slash targets become harmless enchanted ink wisps or lantern charms.
- Orange obstacle targets become angry storm knots or thorn charms.
- The vertical scroll becomes a climb through layered paper clouds and festival lanterns.
- Combo and level feedback should feel bright, snappy, and celebratory instead of violent.

## Fixed Art Style

Use this style for all player, target, hazard, UI, and background assets:

> Polished 2D casual mobile character art, cute heroic proportions, oversized head and hands, compact body, readable silhouette at 64-128 px, clean vector-like shapes, soft cel shading, subtle rim light, expressive face, rounded forms, energetic slash poses, high color contrast, teal/coral/gold accents, warm twilight sky palette, playful but action-focused tone.

Avoid:

- realism
- gore or gritty violence
- horror shapes
- dark cyberpunk neon
- noisy textures
- excessive costume detail that will not read at mobile sprite size
- text embedded in generated images

## Main Character

**Name:** Nori, the Lantern Courier

**Design lock:**

- round face with focused, cheerful expression
- short teal hair tuft
- coral scarf or sash, used as the motion accent
- cream travel coat with small gold accents
- oversized boots and gloves for mobile readability
- small sheathed charm katana, non-threatening and toy-like rather than realistic
- battoujutsu stance: one hand on the scabbard, one hand touching the hilt, knees bent, body angled forward
- silhouette must be readable from the scarf, hair tuft, scabbard line, and compact quick-draw pose

**Base protagonist generation prompt:**

```text
Create the base protagonist character for a casual mobile 2D action game. The hero is a tiny battoujutsu sky courier named Nori. Full-body character concept, readable at 64-128 px, compact cute heroic proportions, oversized head and hands, focused cheerful eyes, short teal hair tuft, coral scarf flowing as the motion accent, cream courier coat, gold toggle buttons, navy shorts or hakama-inspired cropped pants, oversized boots, fingerless gloves, and a small sheathed charm katana. Pose: iai quick-draw stance, knees bent, torso angled forward, left hand gripping the scabbard at the waist, right hand just touching the sword hilt, scarf and coat tails lifted as if about to dash. Mood: playful, brave, fast, non-gory, non-realistic. Clean vector-like shapes, soft cel shading, crisp silhouette, no text, no logo, no UI, no background clutter.
```

## Target Family

**Good targets:** enchanted ink wisps, floating lantern charms, paper seals.

Visual rules:

- round or teardrop silhouettes
- cyan/teal core color
- small white highlight for tappability
- targeted state may shift to coral/pink
- sliced state should burst into paper confetti, ink sparkles, or lantern dust

## Hazard Family

**Bad targets:** angry storm knots, ink thorn charms, overheated lantern sparks.

Visual rules:

- still rounded and cute, but sharper than good targets
- orange/coral warning accents
- dark inner core for contrast
- no teeth, gore, horror faces, or realistic weapons

## OpenAI MCP Configuration Used

Project theme prompt has been set in the OpenAI image MCP:

```text
Project art direction for Quick Draw: a casual mobile 2D action game about a tiny sky courier swordsman slicing through floating enchanted ink targets while climbing upward through a bright paper-lantern sky. Fixed visual style: polished 2D casual mobile character art, cute heroic proportions, oversized head and hands, compact body, readable silhouette at 64-128 px, clean vector-like shapes, soft cel shading, subtle rim light, expressive face, rounded forms, energetic slash poses, high color contrast, teal/coral/gold accents, warm twilight sky palette, playful but action-focused tone. Avoid realism, gore, horror, gritty samurai violence, excessive detail, noisy textures, dark cyberpunk neon, and text in the image.
```

Registered MCP asset kinds:

- `casual_2d_player_character`
- `main_hero_battoujutsu_base`
- `casual_2d_target_character`
- `casual_2d_hazard_character`

Initial player generation target:

```text
Create the base protagonist character for a casual mobile 2D action game. The hero is a tiny battoujutsu sky courier named Nori. Full-body character concept, readable at 64-128 px, compact cute heroic proportions, oversized head and hands, focused cheerful eyes, short teal hair tuft, coral scarf flowing as the motion accent, cream courier coat, gold toggle buttons, navy shorts or hakama-inspired cropped pants, oversized boots, fingerless gloves, and a small sheathed charm katana. Pose: iai quick-draw stance, knees bent, torso angled forward, left hand gripping the scabbard at the waist, right hand just touching the sword hilt, scarf and coat tails lifted as if about to dash. Mood: playful, brave, fast, non-gory, non-realistic. Clean vector-like shapes, soft cel shading, crisp silhouette, no text, no logo, no UI, no background clutter.
```

Intended output path:

```text
assets/images/concepts/nori_battoujutsu_base.png
```

Image generation is currently blocked until `OPENAI_API_KEY` is available in the MCP environment.
