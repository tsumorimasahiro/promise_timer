# Native ad bounds fix — 2026-11-18

Addresses the reported “Advertiser assets outside native ad view” validator warning. The old implementation registered an ad before expanding its collapsed SwiftUI host and used a fixed 380pt height. Long content and larger text need more room: the synthetic full-content case at 320pt width requires 393pt at standard text size and 651pt at Accessibility XXXL.

The card now measures the actual labels and controls using the shared pixel font. It lays out each asset within the native view, reports the required height to SwiftUI, and registers with the SDK only after the host has applied that height and all visible asset frames fit. Missing optional assets get zero frames. The native view retains its required height while its outer host resizes, and no implicit height animation shrinks the ad around its assets. The AdChoices corner stays clear, media preserves its aspect ratio, and the SDK continues to own ad clicks and impressions.

Validation uses 32 synthetic cases on the real layout, live SDK test ads at standard/maximum text sizes, and a live content-size change. Details and the repeatable command are in `Tests/NativeAdLayout/README.md`. JSON receipts and SDK-validator screenshots are saved here. Synthetic tests exercise iPad-sized widths but do not constitute a full iPad UI interaction test or a guarantee for every production creative. The validator remains enabled.

The dedicated simulator and device set are recorded in `simulator.json`; the shared runner shuts down only that device and verifies its state. No user data was erased.

Final Debug build and signed Release archive passed without compiler warnings/errors. All 32 layout cases passed; standard and maximum-size live ads showed “No implementation issues found”. The live size-change run kept all registered assets inside the card (see `native-normal.json` and `native-largest.json`). The simulator runner completed with normal shutdown.

Delivered **1.07 (70)** to the private owner-only internal TestFlight group on 2026-11-18 (JST). API confirmed `VALID`, exactly one tester, no public link and `IN_BETA_TESTING`. Receipts: `testflight-70.json`, `encryption-70.json`; archive identity/source hashes: `build-70.json`. No production App Review submission was made. Xcode upload succeeded with the existing GoogleMobileAds/UserMessagingPlatform vendor dSYM warnings.
