# Retention and purchase experience — 2026-11-17

Implemented against the existing workout app, preserving pre-existing working changes.

- Home/recorded state shows the next cumulative training-day milestone and progress. Rest never reduces earned growth; the final stage has a completion message.
- Repeat the last recorded workout or start a lighter session (at most 5 reps / 15 seconds). Both start session snapshots without changing the saved menu. Preset metadata is retained.
- Weekly summary below the exercise list counts distinct training days and recorded reps/seconds separately, with last week's day count. Non-workout and future records are excluded. Uses the app's locale-aware calendar.
- Optional weekly local reminder, chosen by weekday/time. Permission is requested only on save. Settings also exposes editing/removal; only this feature's notification identifier is removed.
- Purchase screen includes an animated breed preview with workout/rest actions and the user's dog name. Preview never writes profile preferences or entitlements. Existing purchase benefits and pricing are unchanged; this update does not add new costume assets.
- All new copy is localized in Japanese, English, Korean, Simplified Chinese and Traditional Chinese.

Validation: Debug simulator build; retention model regression; existing workout catalog regression; five localization files parsed; whitespace check. UI captures use real SwiftUI screens with synthetic Debug review data on a dedicated iPhone SE (iOS 18.5). Home capture is a review fixture, not an end-to-end workout recording test. Actual StoreKit purchase and scheduled notification delivery were not exercised. iPad and Dynamic Type remain unverified.

Simulator identity and device set are recorded in `simulator.json`. Sessions use the shared lifecycle runner and shut down only that owned device. Captures: `home-se.png`, `premium-se.png`, `reminder-se.png`.

## TestFlight delivery

1.07 (67) was archived, uploaded with API-key authentication, processed as VALID, and assigned only to the `Owner only` internal group (one verified account-holder tester). API readback confirms `IN_BETA_TESTING`; public links and automatic group build distribution are disabled. `autoNotifyEnabled` is true for notifications about this assigned build. No external Beta App Review or production App Review was submitted. Safe receipts: `testflight-67.json`, `encryption-67.json`. Release notes in five locales and review notes are ready locally for a future authorized submission. No production draft or public store metadata was changed.

Upload succeeded with missing-symbol warnings for the vendor GoogleMobileAds and UserMessagingPlatform frameworks. This affects symbolication of crashes inside those vendor binaries, not the successful upload status. Source hashes for app Swift/localization files and project settings are recorded in `build-67-source.json`.
