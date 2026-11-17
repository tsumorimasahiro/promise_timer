# Japanese screenshots — approved sky palette

Re-rendered all five screenshots with the selected pale sky background, dark gray text, and muted orange emphasis. Copy, composition, real screen captures, and pixel artwork are unchanged from the November 17 set. The earlier green version and color studies remain in their original folders.

- Background: `#E8F3F7`
- Text: `#34454C`
- Emphasis: `#A94E24`
- Exports: five opaque RGB PNGs, each 1320 × 2868, in `ja/`.
- `contact-ja.png`: five-image overview.
- `search-preview.png`: 120px per-image preview.
- `pochi-appstore-ja-5.zip`: the five individual PNGs.
- `render-manifest.json`: output and input hashes, palette, and validation.

The calendar uses the previously captured Debug sample-data fixture in `../2026-11-17/raw/ja-calendar.png`; capture provenance is documented in that set's README. No Simulator was started for this color revision.

Re-render from the repository root:

```sh
xcrun swiftc -parse-as-library -module-cache-path .build/ModelTestCache scripts/render_search_store_screenshots.swift -o .build/render-search-store-screenshots
.build/render-search-store-screenshots
```

All five compositions and the reduced search preview were visually inspected. Dimensions, opaque RGB encoding, input hashes, and the ZIP were verified. App code and binaries were not changed for the color revision. These five screenshots were subsequently submitted with app 1.07 (70); see `release/README.md` and `release/submission.json`.
