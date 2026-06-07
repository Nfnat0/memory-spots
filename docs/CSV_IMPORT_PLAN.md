# CSV Import Feature Plan

## Summary

- Add CSV import to append `front` / `back` rows as sticky-note memory items to the currently selected theme in an existing album.
- Distribute rows across the album's photos in `orderIndex` order using the user-specified item count per photo.
- Auto-place items in an even grid within a safe image area, then show a confirmation step before creating the items.

## Key Changes

- Add a "CSV Import" entry point to `MemorySetDetailView` and present an import sheet from the album detail screen.
- In the import sheet, let the user choose a CSV file and set `itemsPerPhoto` with a Stepper. Default to `3`; allow `1...12`.
- After CSV selection, show a confirmation screen with:
  - CSV row count
  - Target theme name
  - Album photo count
  - Items per photo
  - Required photo count
  - Existing item count in the selected theme
- Preserve existing items and append imported items after them. If the selected theme already has items, show a warning in the confirmation screen.
- If the CSV row count exceeds `photo count * itemsPerPhoto`, show a preflight error and do not perform a partial import.

## Interfaces / Data

- Do not change the SwiftData model. No migration is required.
- Add a small import service, for example `CSVMemoryItemImportService`.
  - `parse(data:)` converts CSV data into rows containing `front` and `back`.
  - `assign(rows:photos:itemsPerPhoto:)` maps rows to photos and normalized coordinates.
- CSV format:
  - The first row must include `front` and `back` headers.
  - Column order is flexible.
  - Header matching trims surrounding whitespace and compares case-insensitively.
  - Support comma separators, quoted values, quoted newlines, and escaped quotes using `""`.
  - Prefer UTF-8 / UTF-8 BOM, with Shift_JIS fallback for Japanese Excel CSVs.
- Row handling:
  - Ignore fully empty rows.
  - Treat rows with empty `front` as errors.
  - Allow empty `back`.
- Created `MemoryItem` values:
  - `type: .stickyText`
  - `frontText` / `backText` from CSV values
  - `colorName: "yellow"`
  - `photoId` from the assigned photo
  - `themeId` from the currently selected theme
  - `orderIndex` appended after existing items for each photo
  - `x` / `y` from an even grid inside the safe range `0.18...0.82`; use `0.5, 0.5` for a single item on a photo

## Test Plan

- CSV parser unit tests:
  - Basic `front,back` CSV
  - Swapped column order
  - UTF-8 BOM
  - Japanese Shift_JIS
  - Quoted comma, quoted newline, and escaped quote
  - Missing `front`, missing `back`, empty `front`, and malformed quotes
- Assignment unit tests:
  - Rows are distributed by photo order with `itemsPerPhoto` items per photo
  - Capacity overflow returns an error
  - Grid coordinates stay inside the safe range
  - Single-item placement is centered
- Verification:
  - Run `MindPalaceTests`
  - Run an iOS Simulator build
  - If practical, launch with a sample CSV and confirm notes are added only to the selected theme

## Assumptions

- The import target is always the currently selected theme in the album detail screen.
- Initial implementation does not include replacement, deletion, or column-mapping UI.
- Overflow rows are not automatically assigned to extra photos or packed into the final photo.
- Fine-grained placement adjustments happen later in the existing photo editor.
