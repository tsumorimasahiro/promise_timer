# Japanese App Store screenshot redesign

Five 1320 × 2868 opaque PNGs, in `ja/`, with a five-image overview and a 120px-wide-per-image search-size preview.

1. Companion: an enlarged real workout scene and workout controls.
2. Five repetitions: the real first-workout entry and five-repetition session.
3. Calendar: the app's actual calendar/list components rendered with disposable sample data.
4. Personalization: the app's three free Shiba coat assets and real name/coat controls. No Premium breeds are advertised as free.
5. Pace: real repetition and timer controls.

The compositor crops and enlarges existing app captures without repainting controls or changing their labels. Headline and supporting text sit outside those captures. Pixel artwork uses nearest-neighbor scaling. Existing November 11 and October assets are preserved.

The calendar fixture uses a copied project under `.build/StoreScreenshotFixture`, with changes limited to the existing Debug appearance-review `records` route. Sample dates are November 1, 3, 6, 8, 11, 14, and 17, 2026. The published application source is unchanged. The screenshot explicitly labels the records as sample data. Simulator ownership is recorded in `simulator.json`; the shared lifecycle runner handles shutdown.

Re-render from the repository root:

```
xcrun swiftc -parse-as-library -module-cache-path .build/ModelTestCache scripts/render_search_store_screenshots.swift -o .build/render-search-store-screenshots
.build/render-search-store-screenshots
```

This is a Japanese screenshot delivery only. No store upload, metadata edit, app binary change, or release submission is performed.

Validation: all five exports are 1320 × 2868 RGB PNGs. Full contact sheet and 120px thumbnails visually inspected. Dedicated Simulator verified Shutdown. First launch timed out and was shut down; the second runner session captured the actual calendar successfully and shut down normally. No production application changes were made.
