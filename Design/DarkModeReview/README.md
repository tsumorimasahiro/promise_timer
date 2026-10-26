# Dark appearance review — 2026-10-23

- Device: iPhone 16 Pro Max, iOS 18.5 (A144DFE9-8D3D-4BDA-ACB7-AE28FE91556D). iPhone 18 Pro was not used.
- Build: Debug Simulator and unsigned Release iPhone build succeeded. Logs: `.build/dark-mode-build.log`, `.build/dark-mode-release-build.log`.
- Screens: Home, calendar/day log, promise editor, dog profile, settings and onboarding. Each was captured in dark appearance, then switched live to light appearance in the same process. The appearance review entry reuses the actual app views; editor bindings and record fixtures are disposable sample data. No records were deleted or migrated.
- Contact sheets: `home-records-add.png`, `profile-settings-onboarding.png`. All displayed images were opened and visually reviewed. Initial captures taken before first render were replaced.
- The normal app was also launched. `app-dark.png`/`app-light.png` show first-run onboarding. `app-home-dark.png`/`app-home-light.png` use an argument-domain onboarding-complete override only, preserving stored completion state.
- Palette: named asset colors have light/dark variants. Backgrounds, surfaces, ink, accent, button text, calendar fills and habit colors adapt. Main opaque foreground/background pairs meet 4.5:1; measurements in `contrast.txt` (not a claim covering every translucent/disabled label).
- SpriteKit listens to SwiftUI color scheme changes; dark wall/floor palettes still distinguish morning, daytime and night. Dog texture colors/nearest filtering are unchanged. Widget colors use the same shared catalog, but actual WidgetKit presentation has not been visually captured. Shared export artwork explicitly uses its paper palette.
- Fixed during review: disabled primary button labels were too dark in dark appearance, and fixed white surfaces produced poor contrast.
- The already-submitted 1.04 (64) is unchanged; these changes were not uploaded or submitted. No review cancellation or release change was made.
