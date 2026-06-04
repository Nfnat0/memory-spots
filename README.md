# Memory Spots

Memory Spots is an iOS app for practicing the method of loci with real place photos.

Users build ordered memory routes from familiar photos, reuse the same route with different themes, place visual notes on each photo, and review those notes in their spatial context.

## Current MVP

- Create, rename, search, reorder, and delete memory albums.
- Add place photos from the photo library or camera.
- Read photo location metadata when available and attach camera captures to the current location.
- Add, change, or remove a photo location from a map.
- Browse geotagged photos on a Memory Map with thumbnail pins and album/theme filters.
- Create, select, and delete themes per album.
- Add, edit, drag, and delete theme-specific visual notes on a photo.
- Supported note types: sticky text, image, icon, number label, and arrow.
- Zoom and pan photos while editing.
- Review notes by album and theme, tapping placed notes to reveal answers.
- Seed a global sample album using bundled My Room, Desk Setup, and Local Park photos.

## Tech Stack

- SwiftUI
- SwiftData
- MapKit / Core Location
- PhotosUI / PhotosPicker
- PhotoKit metadata lookup
- FileManager-backed image storage
- ImageIO downsampling
- XcodeGen

The deployment target is iOS 17.0.

## Project Structure

```text
MindPalace/
  Models/                 SwiftData models
  Services/               Image storage, image loading, location, and seed data
  Views/                  SwiftUI screens and shared view utilities
  Resources/SeedImages/   Bundled sample photos
  Resources/Artwork/      App artwork used by onboarding and empty states
docs/                     GitHub Pages support, privacy, and release docs
project.yml               XcodeGen project definition
```

## Getting Started

Generate the Xcode project:

```sh
xcodegen generate
```

Open the project:

```sh
open MindPalace.xcodeproj
```

Or build from the command line:

```sh
xcodebuild \
  -project MindPalace.xcodeproj \
  -scheme MindPalace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

## GitHub Pages

The public support site is served from `docs/` through the Pages workflow:

- Home: `https://nfnat0.github.io/memory-spots/`
- Support URL: `https://nfnat0.github.io/memory-spots/support.html`
- Privacy Policy URL: `https://nfnat0.github.io/memory-spots/privacy.html`

The workflow lives at `.github/workflows/pages.yml` and deploys the static `docs` folder on pushes to `main`.

## Seed Data

On first launch, the app creates a sample memory set with the stable ID `default-seed-set` if it does not already exist.

The seed contains:

- 3 bundled place photos: My Room, Desk Setup, and Local Park
- 1 theme: Grocery List
- 7 sample notes covering everyday items such as milk, apples, bread, coffee beans, a notebook, a water bottle, and dog food
- Sample coordinates so the Memory Map has visible waypoints immediately

Seed image files are copied into the same app-managed image storage used by imported user photos.

## Persistence

SwiftData stores structured records:

- `MemorySet`
- `MemoryPhoto`
- `MemoryTheme`
- `MemoryItem`
- `ReviewResult`

Models use SwiftData relationships with cascade delete rules while still keeping stable UUID fields for straightforward filtering and route logic.

Photo binaries are stored under Application Support through `ImageStore`; SwiftData stores only the image file name. Imported images are downsampled before storage, cached through `ImageLoader` for display, and the photo directory is excluded from iCloud backup.

## MVP Non-Goals

The current MVP intentionally does not include:

- Street View
- AR
- Google Maps SDK
- Advanced image editing
- Advanced SRS
- iCloud sync
- Sharing
- Subscriptions or App Store purchases
- Cloud accounts or external data sync
- AI note placement
