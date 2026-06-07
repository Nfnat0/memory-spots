# Memory Spots: Code & UX Readiness Review

Last updated: 2026-06-07

This review reflects the current MVP implementation of **Memory Spots** after the map, global seed data, visual notes, local image pipeline, and GitHub Pages support pages were added.

## 1. Current Strengths

- The app now uses SwiftData `@Relationship` mappings with cascade delete rules for albums, photos, themes, notes, and review results.
- Seed data uses the stable ID `default-seed-set`, avoiding duplicate seeds when the device language changes.
- The AWS/Gotanda sample route has been replaced by a globally understandable My Room / Desk Setup / Local Park sample.
- The Memory Map gives the product a strong first impression with thumbnail pins, selected-pin animation, filters, and a bottom preview card.
- Photo location handling is flexible: library metadata, camera current location, and manual map editing are all supported.
- `ImageStore` downsamples imported images and excludes the `PlacePhotos` directory from iCloud backup.
- `ImageLoader` provides async image loading and an in-memory cache for repeated photo rendering.
- `GeometryUtils.swift` holds shared aspect-fit geometry used by editor, tutorial, and review surfaces.
- `MemoryItemView` renders the current visual note types consistently across editing and review.
- Support and privacy pages are available under `docs/` for GitHub Pages deployment.

## 2. Remaining Risks

### Dark Mode Consistency

`PalaceStyle` currently defines a deliberately light notebook palette. If the app is meant to stay paper-themed, lock the app to light mode at the root. If Dark Mode is desired, move the palette to semantic assets and verify forms, sheets, maps, and navigation bars in both appearances.

### Review Result Model vs. Current UI

`ReviewResult` and `ReviewGrade` remain in the model layer, but the current review UI focuses on tapping visual notes to reveal answers and does not record remembered/unsure/forgot results. Decide whether result recording is part of 1.0. If not, keep App Store copy aligned with the current reveal-only behavior.

### Localization QA

String catalogs now include English, Japanese, German, French, Italian, Spanish, Korean, and Hindi. Localized UI still needs a full simulator pass, especially for long German and Hindi strings in chips, bottom bars, sheets, and map overlay controls.

### Accessibility QA

The visual-note interaction needs VoiceOver verification. At minimum, confirm that note type, note text, photo title, and map pin purpose are announced clearly and that core flows remain usable without relying only on spatial tapping.

### Static Site Publication

The Pages workflow exists, but the public URLs must be checked after pushing to `main` and enabling GitHub Pages with GitHub Actions as the source.

## 3. App Store Readiness Checklist

| Category | Item | Current Status | Next Action |
| :--- | :--- | :--- | :--- |
| Assets | App Icon | Done | Confirm final branding in App Store screenshots. |
| Legal | Support URL | Prepared | Publish GitHub Pages and verify `support.html`. |
| Legal | Privacy Policy URL | Prepared | Publish GitHub Pages and verify `privacy.html`. |
| Privacy | Privacy Manifest | Done | Re-check if new APIs or SDKs are added. |
| Localization | Info.plist Prompts | Done | Simulator QA in priority locales: Japanese, German, French, Korean, and Hindi. |
| Data Safety | Local Photo Storage | Done | Keep image binaries out of SwiftData. |
| Data Safety | iCloud Backup Exclusion | Done | Re-test if image directory changes. |
| Review Prep | No Login Required | Done | Mention local-only behavior in App Review notes. |

## 4. Recommended Next Tasks

1. Publish and verify the GitHub Pages support site.
2. Run a simulator build and first-launch smoke test.
3. Check priority localized UI for clipped text.
4. Decide whether review result recording belongs in 1.0.
5. Capture App Store screenshots from the current map-first MVP.

## 5. Non-Goals For 1.0

- Street View
- AR
- Google Maps SDK
- Advanced SRS
- Cloud sync
- Sharing
- Subscriptions
- AI note placement
