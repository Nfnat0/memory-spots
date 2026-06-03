# App Store Release Checklist

Last updated: 2026-06-03

## Prepared In This Repository

- App Store metadata draft: `docs/APP_STORE_METADATA.md`
- Support page: `docs/support.html`
- Privacy policy page: `docs/privacy.html`
- GitHub Pages home page: `docs/index.html`
- In-app support and privacy links: `MindPalace/Views/SupportView.swift`
- Privacy manifest: `MindPalace/PrivacyInfo.xcprivacy`

## GitHub Pages Setup

Expected public URLs after GitHub Pages is enabled:

- `https://nfnat0.github.io/mind-palace/`
- `https://nfnat0.github.io/mind-palace/support.html`
- `https://nfnat0.github.io/mind-palace/privacy.html`

Manual setup:

1. Open the GitHub repository settings.
2. Go to Pages.
3. Set the source to deploy from the `docs` folder on the default branch, or use GitHub Actions with a static Pages workflow.
4. Confirm the three URLs above load publicly.
5. Use the support and privacy URLs in App Store Connect.

## Local Verification

Run:

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
- Support sheet opens from the map and album tabs.
- Support and privacy links open in Safari.
- Photo library import still works.
- Camera flow still works on a physical device.
- Location permission copy is understandable in Japanese and English.
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
