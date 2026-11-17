# Home redesign and native ads — 2026-11-17

Implemented the approved home plan, including illustrated exercise buttons.

- One horizontal row of existing exercise illustrations with names, selected border/check, and an add entry at the end. Restores the last successfully completed session; removed exercises fall back safely.
- Compact growth text/bar, one start action, a lighter session option and a sheet for rep/time changes. Starting a light or repeated session never replaces the saved menu.
- Successful completion offers “View today's photo” only when a photo exists, navigating to the records tab. Sharing remains on the actual photo/calendar/album views.
- Weekly home summary is a compact link to records. It separates the start control from the ad, including when all records have been deleted.
- Removed the global fixed banner. Home alone hosts the native ad below the summary. The active session, first-workout flow and Premium remain ad-free. Consent is still managed by the existing UMP flow.
- AdMob UI: created **Home Native** for **ぽちと筋トレ**, application ID matching AppInfo.plist. Production/native and Debug/test IDs are separate; existing server-side banner units were preserved for installed older builds. See `admob.json`.
- NativeAdView registers SDK asset views and clicks, clearly labels advertising, leaves the AdChoices corner clear, supports MediaView/video starting muted, preserves aspect ratio, and collapses unavailable/failed requests. Exercise selection does not reload the ad. No live ad was clicked.

The last-success snapshot is saved only after record persistence succeeds. Legacy installations without that snapshot use their existing logs until their next completed workout. Existing record/history data and purchase entitlements are preserved.

Validation: retention/home-selection model regressions; existing workout-catalog regression; localization parsing in five languages; whitespace checks. The iPhone SE test-ad capture shows Google's Native Validator reporting **No implementation issues found**. The native screen and home captures use real app view implementations with Debug review entry points and synthetic home data, not an end-to-end recording/purchase test. Actual production fill and device notification delivery are not established by these captures.

Simulator device sets and owned UDIDs are recorded in `simulator.json` and `simulator-ipad.json`. Each capture uses the shared lifecycle runner and shuts down only its own device. No Simulator data was erased.

Released to owner-only internal TestFlight as **1.07 (68)** on 2026-11-17. Signed archive and upload succeeded; Apple confirmed `VALID`, and the sole `Owner only` group has one tester, no public link, and `IN_BETA_TESTING`. Receipts: `testflight-68.json`, `encryption-68.json`; archive identity and source hashes: `build-68.json`. No production App Review submission was made. Xcode reported missing vendor dSYMs for GoogleMobileAds and UserMessagingPlatform; the upload and TestFlight processing still succeeded.

Final verification: Debug simulator and Release device builds passed without warnings/errors. The final iPad capture also shows Native Validator reporting no implementation issues. An initial zero-height/loading lifecycle issue found on iPad was fixed by starting the SDK request in the host's viewDidLoad (rather than waiting for viewDidAppear); the unloaded placement can now remain collapsed. Both owned simulator sessions finished with normal shutdown. Large Dynamic Type, landscape interaction and real production-ad fill were not exercised.
