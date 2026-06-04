# AGENTS.md

Guidance for coding agents working in this repository.

## Project Goal

Memory Spots is an iOS MVP for practicing the method of loci with place photos. Keep the app focused on:

- Memory sets made from ordered place photos.
- Themes that switch note content on the same photo route.
- Sticky-note style memory items placed on photos.
- Simple review by memory set and theme.

Do not add Street View, AR, advanced SRS, cloud sync, sharing, subscriptions, or speculative AI features unless explicitly requested.

## Working Principles

- State assumptions before implementing when the request is ambiguous.
- Prefer the smallest change that satisfies the user request.
- Match the current SwiftUI and SwiftData style.
- Avoid broad refactors while implementing feature work.
- Remove only unused code introduced by your own change.
- Verify with a simulator build when Swift code or project configuration changes.

## Build And Project Commands

This project uses XcodeGen. Regenerate the project after changing `project.yml` or resource layout:

```sh
xcodegen generate
```

Build for simulator:

```sh
xcodebuild \
  -project MindPalace.xcodeproj \
  -scheme MindPalace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

When available, prefer XcodeBuildMCP simulator tools for build and run verification.

## Architecture Notes

- `MindPalaceApp.swift` installs one SwiftData model container at the app root.
- `Models/MemoryModels.swift` contains the persisted model types.
- `Services/ImageStore.swift` stores photo binaries in Application Support and returns file names.
- `Services/SeedDataService.swift` inserts the bundled AWS sample set on first launch.
- `Views/HomeView.swift` is the root navigation screen.
- `Views/MemorySetDetailView.swift` handles themes, photos, and review entry.
- `Views/PhotoEditorView.swift` handles note placement and editing.
- `Views/ReviewView.swift` handles card review.

## Data Rules

- Do not store image binaries in SwiftData.
- Keep `MemoryPhoto.imagePath` as the stored file name or relative path.
- Keep note coordinates normalized from `0.0` to `1.0` within the displayed image.
- Preserve theme isolation: a photo editor must show only notes for the selected theme.
- When deleting a set, photo, or theme, delete dependent notes and review results.

## Seed Data Rules

- Seed data must be idempotent.
- Do not create duplicate `AWS資格 五反田ルート` sets on repeated launches.
- Bundled seed photos live in `MindPalace/Resources/SeedImages`.
- If seed resources change, update `project.yml` and regenerate the Xcode project.

## UI Guidelines

- Let photos be the main visual surface.
- Keep operational UI clear and compact.
- Use standard SwiftUI controls before custom controls.
- Use cards only for repeated content or framed tools.
- Keep sticky notes lightweight and readable.

## Verification Checklist

After code or project changes:

1. Run `xcodegen generate` if `project.yml` or resources changed.
2. Build the app for an iOS simulator.
3. For persistence or seed-data changes, launch the app and confirm it does not crash.
4. For note placement changes, check both portrait and landscape behavior when practical.

