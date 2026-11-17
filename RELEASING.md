# App Store releases through the API

Use the official App Store Connect API for future releases, as requested on 2026-11-11. App: `6760613210`; bundle: `max.promise-timer`; team: `36RR696644`.

## Latest App Review submission

Version **1.07 (70)** was submitted with the five approved sky-background Japanese iPhone screenshots on 2026-11-18 JST. Apple confirmed `WAITING_FOR_REVIEW`; release after approval remains automatic. Submission, media verification, source-hash verification and metadata are in `Design/AppStore/2026-11-18/release/`. The uploaded build already matched all current app/widget source hashes, so it was reused. Other locale/device media and previews were preserved.

After a successful review submission, commit and normally push the matching app source, required release assets and safe receipts to the existing GitHub branch, then verify the remote commit. Exclude private credentials, build products and unrelated changes. This is the user’s standing release instruction; no additional confirmation is needed.

## Authentication

The ignored `.asc-private/config.json` references an existing team API key with App Manager access. Keep that file and the `.p8` private. The key remains in its existing local storage; do not move or revoke it without checking other projects that use it. Team keys apply across the team's apps; every command below explicitly targets this app.

The scripts use Python 3.9+ standard library and the system OpenSSL. No Apple Account browser session, password, third-party Python package, or JWT pasted into a command is required. The scripts accept `--config` or `ASC_CONFIG`; a template is:

```json
{
  "key_type": "team",
  "key_id": "YOUR_KEY_ID",
  "issuer_id": "YOUR_ISSUER_ID",
  "key_path": "/private/local/path/AuthKey_YOUR_KEY_ID.p8"
}
```

## Build and upload

Before building or uploading, run `python3 scripts/check_pixel_fonts.py`. App-owned text must keep the shared pixel font; see `AGENTS.md` and `promise_timer/PochiTypography.swift`. Owner-only TestFlight distribution also runs this check before contacting Apple. This static guard checks common font overrides, root defaults and bundled app/widget fonts; it complements visual checks rather than replacing them.

Standing user instruction from 2026-11-17: every completed app change includes relevant validation, a new signed build, and owner-only internal TestFlight distribution. No additional confirmation is needed. Keep the app and widget build numbers aligned, verify the remote build number before upload, and confirm `VALID` plus `IN_BETA_TESTING` with exactly the owner as tester. Documentation-only changes do not need another upload. Production App Review remains a separate explicitly requested action.

Increment the app and widget version/build together, run relevant checks, and create a signed Release archive. For upload, read the local config and pass its key file path and identifiers to Xcode. Do not print the key, JWT, or config:

```python
import json
import subprocess
from pathlib import Path

config = Path('.asc-private/config.json').resolve()
auth = json.loads(config.read_text())
key = Path(auth['key_path']).expanduser()
if not key.is_absolute():
    key = config.parent / key
subprocess.run([
    'xcodebuild', '-exportArchive',
    '-archivePath', '.build/PochiWorkout-VERSION-BUILD.xcarchive',
    '-exportOptionsPlist', '.build/SubmissionExportOptions.plist',
    '-exportPath', '.build/SubmissionExport',
    '-allowProvisioningUpdates',
    '-authenticationKeyPath', str(key),
    '-authenticationKeyID', auth['key_id'],
    '-authenticationKeyIssuerID', auth['issuer_id'],
], check=True)
```

The export options use `method=app-store-connect`, `destination=upload`, `signingStyle=automatic`, `manageAppVersionAndBuildNumber=false`, and team `36RR696644`. Check the API before retrying an upload after an ambiguous connection failure.

## Prepare, verify, and submit

The commands below document release 1.06 (66). Change version, build, asset paths, and receipts together for the next release. `prepare` changes draft metadata and build selection; it does not submit. It preserves accepted keywords, review contact information, and release behavior by default.

```sh
python3 scripts/app_store_connect.py --config .asc-private/config.json --version 1.06 --build 66 inspect --output .build/asc-inspect.json

python3 scripts/app_store_connect.py --config .asc-private/config.json --version 1.06 --build 66 prepare --listing Design/AppStore/2026-11-11/release-listing.json --review-notes Design/AppStore/2026-11-11/review-notes.txt --no-demo-account --output .build/asc-prepared.json

python3 scripts/app_store_media.py plan --app-id 6760613210 --version 1.06 --config .asc-private/config.json --assets Design/AppStore/2026-11-11 --receipt .build/asc-media-plan.json

python3 scripts/app_store_media.py upload --execute --app-id 6760613210 --version 1.06 --config .asc-private/config.json --assets Design/AppStore/2026-11-11 --receipt .build/asc-media-receipt.json

python3 scripts/app_store_connect.py --config .asc-private/config.json --version 1.06 --build 66 submit --prepared .build/asc-prepared.json --output .build/asc-submitted.json
```

The media script uses Apple's App Asset Library API and current device specifications. It verifies local files, waits for processing, and preserves iPad and untargeted placements. It journals asset IDs for resumable uploads; keep `.build/asc-media/` while a release is in progress. Only the 20-second App Store preview is submitted; the 12-second social video is not an App Store preview. The default upload variant is `video/appstore-ja-20s-upload.mp4` with `video/upload-manifest.json`; it adds a silent AAC track required by Apple's current specification while preserving the original video stream.

If the exact build has a missing encryption declaration, review the source and dependencies before explicitly setting the answer. For 1.06 (66), no non-exempt encryption was introduced and the previous builds' `false` answer was verified and applied with:

```sh
python3 scripts/app_store_connect.py --config .asc-private/config.json --version 1.06 --build 66 declare-encryption --uses-non-exempt-encryption false --output .build/asc-encryption.json
```

Before `submit`, verify the correct build is VALID, all requested metadata reads back, every media placement is ready, and the intended release mode is preserved. The submit script guards app/version/build identity and metadata changes, and refuses unrelated review items. Re-running a confirmed submission returns its existing state instead of creating another one. Keep the safe submission receipt in the dated `Design/AppStore/` folder, and report success only when the API confirms `WAITING_FOR_REVIEW` or a later submitted state.

For 1.06, Apple required the new age-rating answers `socialMedia` and `socialMediaAgeRestricted`. Both were set to `false` after reviewing the [official definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/): the app has no feed, content discovery, or in-app social distribution; its cards are exported through the system share sheet. Other answers were preserved. Read the editable app's declaration through `/v1/appInfos/{id}/ageRatingDeclaration` before updating it; use that returned declaration ID, not an ID inferred from a submission error. Reassess these answers if social functionality changes. Evidence: `Design/AppStore/2026-11-11/api-age-rating.json`.

Official references: [API overview](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api), [JWT authentication](https://developer.apple.com/documentation/appstoreconnectapi/generating-tokens-for-api-requests), [asset specifications](https://developer.apple.com/documentation/appstoreconnectapi/discovering-asset-specifications), [review submissions](https://developer.apple.com/documentation/appstoreconnectapi/post-v1-reviewsubmissions).

## Script regression checks

Run `python3 Tests/AppStoreAPI/test_workflow.py` after changing the API workflow. These tests need no credentials and block external network connections. They cover submission identity, repeated execution, ambiguous writes, replacement failure, and preservation of untargeted media. Live readback remains necessary for each release.

The live API on 2026-11-11 returned placement state `ACTIVE`, while the published OpenAPI 4.6 listed `PARENT_*` states. The media script accepts `ACTIVE` only after verifying its exact parent locale, device group, asset linkage, asset processing, and specification. It requests relationships explicitly with `include`; default responses can omit them. Missing `specId` immediately after upload is treated as pending processing. Ordering requests must contain a single placement type, so screenshots and previews are ordered and verified separately. GET network failures are retried within a bound; ambiguous writes are never automatically repeated.

## Owner-only TestFlight

Latest delivered build: **1.07 (70)**, fixing native-ad asset containment and registration timing with content-sized layout. Apple confirmed `VALID` and owner-only `IN_BETA_TESTING` on 2026-11-18 (JST). Receipt: `Design/NativeAdBoundsReview/testflight-70.json`. Earlier build receipts remain in their review folders. The examples below retain the previous build 67 for historical context; use explicit current version/build arguments for each new upload and distribution.

The signed 1.07 (67) archive contains the retention and purchase-preview changes.
`testflight_owner.py` verifies this app and requires the sole App Store Connect user to be the account holder. It creates/reuses an internal `Owner only` group with no public link and no automatic distribution. Tester lookup is scoped to this app (Apple can return separate tester records for the same email across apps). It refuses other recipients rather than removing them.

```sh
# Preview is read-only; --execute is required for writes.
python3 scripts/testflight_owner.py setup
python3 scripts/testflight_owner.py setup --execute --output .build/retention-beta-group.json
# After uploading and waiting for VALID (and declaring encryption if needed):
python3 scripts/testflight_owner.py distribute --version 1.07 --build 67 --execute --output .build/retention-testflight.json
python3 Tests/AppStoreAPI/test_testflight_owner.py
```

The standard App Store upload is intentional: this same build may later be selected for App Review. Do not use `testFlightInternalTestingOnly` when a future App Store submission of the exact build is desired. Only the owner group receives this build; no Beta App Review or App Review is submitted by the TestFlight script.

For a later authorized App Review submission, use the existing `prepare` / media / `submit` workflow above with `--version 1.07 --build 67`, updated release notes, and a new preparation receipt. Validate media and draft metadata first. The current TestFlight request does not authorize a production review submission.

Live API detail: `GET /v1/builds/{id}/betaGroups` is not supported. Read assigned groups with `/v1/betaGroups?filter[builds]=BUILD_ID` (do not combine with another relationship filter). Individual tester IDs are read through the build's explicit `include=individualTesters`; incomplete paging is refused. Confirmed 1.07 (67) receipt: `Design/RetentionReview/testflight-67.json`, internal state `IN_BETA_TESTING`.
