# Typography

- Standing user instruction (2026-11-18): keep all app-owned text in the bundled PixelMplus12-Bold pixel font. Do not mix in system, rounded, or other typefaces in future changes, including new screens, input fields, advertisements and widgets.
- Use `pochiPixelFont` for SwiftUI and `pochiPixelUIFont` for UIKit, defined in `promise_timer/PochiTypography.swift`. Use `pochiNavigationTitle` for visible navigation titles. Preserve the app-root default font, Dynamic Type scaling and app/widget font registration.
- System font modifiers are allowed only on SF Symbol images to control icon size. OS/SDK-owned surfaces and missing-glyph fallback are outside the app's typography control. Do not use these exceptions for ordinary app text or add broad lint suppressions.
- Run `python3 scripts/check_pixel_fonts.py` before completing UI work and before any release. Fix failures rather than weakening the check. Check affected layouts for clipping on a small device when changing typography.

# Release workflow

- The user prefers App Store Connect API for future releases. Use the official API scripts in `scripts/` for release metadata, media, build selection, and review submission. Use API-key authentication for `xcodebuild` uploads as well.
- Read `RELEASING.md` before a release. Local authentication configuration is `.asc-private/config.json`; it is intentionally ignored by Git. Never print or commit private keys, JWTs, or credential configuration.
- Standing user instruction (2026-11-17): after completing app changes and relevant validation, increment the app/widget build together, upload a signed build via API-key authentication, and distribute it to the owner-only internal TestFlight group. Do this for each app change without asking again. Verify VALID processing, exactly one owner tester, and IN_BETA_TESTING before reporting success. Documentation-only changes do not require a new build. TestFlight distribution does not itself authorize production App Review submission.
- The app is `6760613210`, bundle ID `max.promise-timer`. Always verify the app, version, and build before changing remote state. Preserve other apps and existing pricing, privacy declarations, purchases, and accepted metadata outside the requested release scope.
- A request to submit to App Review authorizes the submission. Do not request redundant confirmation for an already authorized release. Report completion only after the API confirms the submitted state.
