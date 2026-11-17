# App Review submission — 1.07 (70)

Submitted through the App Store Connect API on 2026-11-18 JST (2026-11-17T23:55:42.523Z). Apple confirmed `WAITING_FOR_REVIEW` for submission `e2f2d098-7a28-421c-aebb-e43a2045e8bd`. Automatic release after approval is retained.

The submitted binary is the existing signed 1.07 (70), build ID `5c94b029-4d19-427c-8c49-35972f09f1ba`. All 64 source hashes in `Design/NativeAdBoundsReview/build-70.json` match the current app/widget source. No binary changes were made during this screenshot submission. Owner-only TestFlight was freshly verified as VALID / IN_BETA_TESTING with exactly one tester.

Five Japanese iPhone screenshots use the approved pale sky palette. `screenshot-upload-map.json` maps the reviewed source filenames to the existing media script's upload aliases, in order. Copies were staged under ignored `.build/asc-107-assets/ja/`; their hashes are unchanged. Upload used `--locales ja --skip-preview`. The API readback confirmed all five active placements in order. Other languages, iPad placements and existing previews match the previous published version. The existing description, keywords, support/marketing URLs and release mode are retained; only What's New was updated in all five locales.

Evidence:
- `submission.json`: API-confirmed review submission.
- `prepared-107.json`: exact version/build and metadata fingerprint.
- `media-upload.json`, `media-verification.json`: completed upload, ordered image IDs and preserved media.
- `release-listing.json`, `release-notes.json`, `review-notes.txt`: submitted metadata.
- `testflight-verification.json`, `validation.json`: release checks.

The font guard, 4 typography guard tests, 31 API workflow tests, retention regression and workout catalog regression passed. Existing signed-build, small-device UI and 32 native-ad layout cases remain applicable because the binary source hashes match. No Simulator was started for this submission. No new purchase, privacy, age-rating or pricing changes were included.
