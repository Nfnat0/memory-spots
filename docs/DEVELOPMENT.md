# Development Notes

Last updated: 2026-06-05

## Success Criteria For The MVP

- A memory album can be created, renamed, searched, reordered, and deleted.
- Multiple photos can be added to an album from the library or camera.
- Photos can be saved with a location when metadata or current location is available.
- Photos without a location can still be saved and edited later.
- Geotagged photos appear on the Memory Map with thumbnail pins.
- The map can be filtered by album and theme.
- Themes can be created, selected, and deleted.
- The same photo can show different notes depending on the selected theme.
- Visual notes can be added, edited, moved, and deleted on a photo.
- Supported note types are sticky text, image, icon, number label, and arrow.
- Review can run for an album and theme by showing photos in route order and revealing placed note answers.
- Data persists after app relaunch.

## Main User Flows

1. Open the app and complete the short tutorial.
2. Start from the Memory Map or choose an album from the Albums tab.
3. Add place photos from the library or camera.
4. Add or adjust photo locations as needed.
5. Select or create a theme.
6. Open a photo and place visual notes.
7. Start review for the selected album and theme.

## Persistence Model

The app uses SwiftData models with cascade relationships:

- `MemorySet` owns photos and themes.
- `MemoryPhoto` owns memory items.
- `MemoryTheme` owns theme-specific memory items.
- `MemoryItem` owns review results.

UUID fields remain on the models for simple filtering, ordering, and route logic. Image files are managed separately by `ImageStore`, not stored in SwiftData.

## Image Storage

`ImageStore` writes photo binaries under Application Support in the `PlacePhotos` directory. The directory is excluded from iCloud backup.

Imported image data is downsampled to a maximum pixel size of 2048 before storage. `ImageLoader` provides async loading and in-memory caching for SwiftUI views.

## Review Behavior

Review is intentionally simple:

- Show photos in album route order.
- Show the placed visual notes for the selected theme.
- Reveal a note's answer when the user taps it.

There is no scheduling algorithm or advanced scoring in the current MVP.

## GitHub Pages

The `docs/` folder is a static support site for App Store review. The Pages workflow deploys it on pushes to `main`.

Public URLs:

- Home: `https://nfnat0.github.io/memory-spots/`
- Support: `https://nfnat0.github.io/memory-spots/support.html`
- Privacy: `https://nfnat0.github.io/memory-spots/privacy.html`
