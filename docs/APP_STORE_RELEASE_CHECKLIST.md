# App Store Release Checklist

Last updated: 2026-06-07

## Prepared In This Repository

- App Store metadata draft: `docs/APP_STORE_METADATA.md`
- Support page: `docs/support.html`
- Privacy policy page: `docs/privacy.html`
- GitHub Pages home page: `docs/index.html`
- Static Pages workflow: `.github/workflows/pages.yml`
- Privacy manifest: `MindPalace/PrivacyInfo.xcprivacy`
- App icon asset: `MindPalace/Assets.xcassets/AppIcon.appiconset/icon-1024.png`
- Localized Info.plist strings: `MindPalace/InfoPlist.xcstrings`
- Localized UI strings: `MindPalace/Localizable.xcstrings`
- Public support artwork copied into `docs/assets/`
- iPhone App Store screenshots: `screenshots/app-store/captioned/*.png` at 1284 x 2778

## GitHub Pages Setup

Verified public URLs:

- `https://nfnat0.github.io/memory-spots/`
- `https://nfnat0.github.io/memory-spots/support.html`
- `https://nfnat0.github.io/memory-spots/privacy.html`

Recommended setup:

1. Open the GitHub repository settings.
2. Go to Pages.
3. Set the source to GitHub Actions.
4. Push the `docs/**` changes to `main`, or run the `Deploy GitHub Pages` workflow manually.
5. Confirm the three URLs above load publicly.
6. Use the support and privacy URLs in App Store Connect.

Fallback setup:

- If not using GitHub Actions, configure Pages to publish from the `docs` folder on the default branch.

## Local Verification

Metadata length checks:

- App name: within 30 characters.
- Subtitle: within 30 characters.
- Promotional text: within 170 characters.
- Description: within 4,000 characters.
- Keywords: within 100 characters.
- What's New: within 4,000 characters.

Screenshot status:

- iPhone 6.5-inch screenshots are prepared at 1284 x 2778.
- Captioned screenshots can be regenerated with `python3 scripts/render_app_store_screenshots.py --repo .`.
- The app currently targets iPhone and iPad (`TARGETED_DEVICE_FAMILY = "1,2"`), so prepare iPad screenshots before submission or intentionally switch the app to iPhone-only.

For docs-only changes, verify the static site locally:

```sh
cd docs
python3 -m http.server 8000
```

Then open:

- `http://127.0.0.1:8000/`
- `http://127.0.0.1:8000/support.html`
- `http://127.0.0.1:8000/privacy.html`

For Swift code or project changes, run:

```sh
xcodegen generate
xcodebuild \
  -project MindPalace.xcodeproj \
  -scheme MindPalace \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

For release readiness, also launch on a simulator and check:

- First launch tutorial appears.
- Memory Map shows sample waypoints.
- Album list opens the seeded sample album.
- Theme chips switch note content.
- Photo library import still works.
- Camera flow still works on a physical device.
- Permission copy is understandable in priority locales: Japanese, German, French, Korean, and Hindi.
- Photos without locations can be saved and edited later.
- Photo editor supports sticky text, image, icon, number, and arrow notes.
- Review screen reveals note answers.
- Deleting albums/photos/themes removes dependent data.

## App Store Connect Items Still Requiring Account Access

- App record creation.
- Bundle ID/capability confirmation.
- Screenshot upload.
- Privacy answers publication.
- Age rating questionnaire.
- Pricing and availability.
- TestFlight or production build upload.
- Final submission to App Review.
