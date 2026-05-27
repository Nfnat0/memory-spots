# Mind Palace

Mind Palace is an iOS app for practicing the method of loci with real place photos.

Users create memory sets from multiple location photos, switch study themes on the same route, place sticky-note style memory cards on each photo, and review those cards in order.

## Current MVP

- Create, rename, and delete memory sets.
- Add place photos from the photo library or camera.
- Store image files in app storage instead of SwiftData.
- Create, select, and delete themes per memory set.
- Add, edit, drag, and delete theme-specific notes on a photo.
- Review cards by memory set and theme.
- Record simple review results: `覚えた`, `微妙`, `忘れた`.
- Seed an AWS certification sample set from bundled Gotanda route photos.

## Tech Stack

- SwiftUI
- SwiftData
- PhotosUI / PhotosPicker
- Core Location
- FileManager-backed image storage
- XcodeGen

The deployment target is iOS 17.0.

## Project Structure

```text
MindPalace/
  Models/                 SwiftData models
  Services/               Image storage, location, and seed data
  Views/                  SwiftUI screens
  Resources/SeedImages/   Bundled sample photos
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

## Seed Data

On first launch, the app creates a sample memory set named `AWS資格 五反田ルート` if a set with that name does not already exist.

The seed contains:

- 3 bundled place photos
- 1 theme: `AWS資格`
- 12 AWS certification notes across IAM, VPC, S3, RDS, DynamoDB, monitoring, and architecture basics

Seed image files are copied into the same app-managed image storage used by imported user photos.

## Persistence

SwiftData stores structured records:

- `MemorySet`
- `MemoryPhoto`
- `MemoryTheme`
- `MemoryItem`
- `ReviewResult`

Photo binaries are stored under Application Support through `ImageStore`; SwiftData stores only the image file name.

## MVP Non-Goals

The current MVP intentionally does not include:

- Street View
- AR
- Google Maps SDK
- Advanced image editing
- Image collage tools
- AI note placement
- Advanced SRS
- iCloud sync
- Sharing
- Subscriptions or App Store purchases

