# App Store listing refresh — 2026-10-22

## Prepared
- Japanese name: ぽちログ - わんこと続ける習慣
- English name: PupHabit - Habits with a Pup
- Korean / Simplified Chinese / Traditional Chinese names also use PupHabit, with localized habit wording.
- `listing.json`: five locales of name, subtitle, description, promotional text and screenshot headlines. All field lengths validated. Existing standard EULA link retained.
- `STORE_LISTING_COPY.md`: matching human-readable copy (replaced obsolete bond/6-habit/subscription/collar claims).
- Each locale directory contains six opaque RGB 1320×2868 PNGs: home, promises sheet, memories album, profile, habit templates, history. Original simulator captures are in `raw/`; previews are `*-preview.png`.
- Short headline + actual captured screen only. No AI-generated screens, extra badges, fake ratings, or painted UI. Native CoreGraphics/CoreText compositor: `scripts/render_store_screenshots.swift`.
- Screenshot size reference: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/

## Actual verification
- Dedicated iPhone 16 Pro Max / iOS 18.5 simulator, UUID D51E0C89-3BA8-479C-9FAC-7F3D161F8305, named PupHabit Store Screenshots. No iPhone 18 Pro was used.
- Onboarding completed through the UI with three sample habits. Breakfast recorded through the real flow; dog food reaction seen. Photo captured, saved, and reopened in the album. No real user data was used.
- Actual UI captured in Japanese, English, Korean, Simplified Chinese and Traditional Chinese, with each set visually reviewed via contact sheet.
- Found first-open photo sheet blank: replaced split photo/Boolean states with one identifiable captured photo item, then rebuilt and confirmed sheet + save + album via UI.
- Debug-only `-pochi-store-screenshots` suppresses the test ad creative during captures; production ad behavior unchanged.
- Build successful, no warning/error lines in `.build/store-screenshots-build.log`; `git diff --check` passed.
- iPad screenshots are not included in this set.

## App Store Connect — 1.04 draft saved
- User explicitly authorized creating a new version and requested six screenshots.
- Created iOS 1.04; verified status 提出準備中. Released 1.03 remains separate.
- Added en-US, ko, zh-Hans and zh-Hant alongside ja.
- Saved names, subtitles, descriptions and promotional text in all five locales. Reopened app information and verified all five names/subtitles.
- Japanese name: ぽちログ - わんこと続ける習慣. Overseas names use PupHabit with localized suffixes.
- Proof: `asc-ja-name-saved.png`, `asc-en-name-saved.png`, `asc-1.04-draft.png`.
- No build uploaded or selected, no review submission, no release.
- Existing keywords, What's New, support/privacy/contact/review settings retained. Keywords remain Japanese in newly copied locales; localization of keywords and new release notes should be completed before submission.

## Screenshots — completed locally, upload blocked
- Six images per locale, 30 total. Profile was recaptured with its sheet expanded so name and three coat choices are visible. All five final contact sheets visually inspected.
- Actual iPhone 16 Pro Max iOS 18.5 capture. No iPhone 18 Pro used.
- Native Safari media manager's large Dynamic Island iPhone slot accepts 1320×2868 according to visible UI.
- File picker displays valid PNGs, can select one or all six, but Upload remains disabled. Tried direct file path, folder multi-selection, keyboard selection, reopening picker and a /tmp copy; none enabled Upload. Coordinate interaction additionally returns noWindowsAvailable. Root cause not established; do not report remote screenshot upload complete.
- `upload-picker-blocked.png` records disabled Upload with a selected PNG.
- Existing four Japanese screenshots remain attached; no screenshots removed or uploaded. Other language screenshots may inherit Japanese assets until replaced.
- Each locale's numbered files are ordered 01 home, 02 promises, 03 memory, 04 profile, 05 habits, 06 history. `*-preview.png` is a review sheet, not an upload asset.

## Resume
1. Open the existing 1.04 draft; do not create another version.
2. Restore a functioning native file picker/upload interaction, then upload six numbered PNGs from each language directory to that locale's large iPhone screenshot slot.
3. Replace only obsolete draft screenshot attachments; preserve other assets and live 1.03. Verify six new screenshots and order in every locale.
4. Recheck smaller-iPhone inheritance and iPad assets before future submission (no new iPad set was prepared).
5. Finish localized keywords / release notes if requested for submission. No build upload or review submission is authorized in this task.

## Upload retry requested by user
- Retried in zh-Hant large Dynamic Island iPhone slot. Selected all six PNGs in name order, then switched the native picker to column view and tried a single PNG.
- Upload remained disabled in both modes. Native preview confirms 1320×2868 PNG dimensions. Coordinate click still returned `noWindowsAvailable`.
- No files uploaded or old attachments removed. Restored list view and cancelled picker. Evidence: `upload-retry-blocked.png`.

## Lifetime product created; follow-up pricing pending
- Created NON_CONSUMABLE `promise_timer.premium.lifetime`, Apple product ID `6825802653`, reference Pochi Premium Lifetime. Do not create a duplicate.
- Saved initial price: Japan JPY 3,900 with Apple equivalents (US USD 24.99). Product remains 提出準備中, not submitted.
- Saved Japanese name and description. Other four product localizations still pending.
- User explicitly approved all 175 territories after automatic approval review rejected initial availability confirmation. Approval now exists; do not ask again. Availability has NOT been saved.
- Latest user pricing override: Japan stays JPY 3,900; overseas should be JPY 5,900 equivalent in local price points. Overseas update NOT yet saved.
- Native Safari scroll failed with `noWindowsAvailable`, subsequent keyboard interactions did not change AX state. Screenshot and AX modal states diverged. Root cause unconfirmed; do not claim a verified OS lock.
- Screenshot upload remains incomplete. Subscription availability has NOT yet been inspected or changed.
- App code already offers only lifetime for new purchases, preserves verified legacy active entitlements and restore. No app code changed this session.
- Resume at existing IAP product URL /apps/6760613210/distribution/iaps/6825802653: finish worldwide availability, overseas pricing override, remaining localizations, review screenshot; then inspect legacy subscriptions and retry six screenshots for each of five locales. Do not upload a build or submit review.

## Unlocked Safari retry
- Native scrolling works after user unlocked Mac. Saved worldwide availability (175 territories).
- Saved overseas-only custom price change: 174 territories based on JPY 5,900. Reopened current-price popover and verified Japan JPY 3,900 and US USD 39.99. Evidence lifetime-prices-saved.png.
- First six-file Japanese upload reached 10/10 with four old attachments, but only three new assets appeared processed in library. Removed all Japanese large-iPhone attachments via reversible detach (UI explicitly says assets remain in library), then re-uploaded the six new files. Awaiting processing verification. Live 1.03 untouched.

- Japanese legacy draft screenshots detached (remain recoverable in asset library). New ja/en-US/ko/zh-Hans/zh-Hant each shows 6/10, ordered 01–06. All 30 files accepted; processing/thumbnail recheck still pending.


## 2026-10-22 — Unlocked Safari retry: final verification
- App Store Connect iOS 1.04 draft: ja, en-US, ko, zh-Hans, zh-Hant each contain exactly six screenshots (01–06), 30 total. All six thumbnails in each locale were visually checked after Apple processing; zh-Hant recovered after reload.
- Evidence: Design/AppStore/2026-10-22/asc-{locale}-six-uploaded.png.
- Lifetime product 6825802653: all 175 territories saved; Japan JPY 3,900; 174 overseas territories use Apple equivalents of JPY 5,900 (USA USD 39.99). Overseas prices are manually managed. Five product localizations saved.
- Legacy monthly/yearly remain available: action-time consent pending for Apple's end-of-current-billing-cycle service/refund agreement. Do not accept or stop until user replies to pending question.
- Product review screenshot still missing; no review submission, release, or binary upload performed.
- No application code changes or build/tests in this store-configuration session.


## 2026-10-22 — Legacy subscriptions stopped
- User explicitly approved stopping both after the Apple service/refund conditions were explained.
- Monthly promise_timer.monthly (6760938401) and yearly promise_timer.yearly (6760938390): confirmed Developer Removed from Sale and 0 of 175 territories selected. New purchases and renewals stopped according to Apple's confirmation.
- Evidence: Design/AppStore/2026-10-22/subscription-monthly-stopped.png and subscription-yearly-stopped.png.
- Existing billing-period entitlements remain supported; product records were not deleted. No binary upload or review submission.


## 2026-10-23 — App Review submission in progress
- User authorized submission and keyword updates. All five locale keywords and release notes saved; review notes updated for the new lifetime product. Copy: Design/AppStore/2026-10-22/submission-listing-updates.json.
- Release archive 1.04 (64) created successfully with signing. Existing cached SwiftPM artifact path corrected to local .build/SourcePackages.
- xcodebuild export/upload succeeded. GoogleMobileAds and UserMessagingPlatform vendor dSYMs were missing (non-blocking upload warnings). Build 64 processed and attached to 1.04 draft.
- Export compliance answer pending explicit user consent after automatic approval review blocked the attestation (static app-source search alone did not verify SDK encryption). Async confirmation question sent; do not bypass.
- Lifetime IAP review notes saved. Review screenshot being prepared using actual UpgradeView and local StoreKit testing, isolated to DEBUG simulator; Release 64 is unaffected.
- No App Review submission completed yet. Resume with export compliance consent, IAP screenshot upload/add to review, version add to review, then final submit and verify Waiting for Review.


## 2026-10-23 — Submitted successfully at 00:15 JST
- App 1.04 (64) and Pochi Premium Lifetime both visibly WAITING FOR REVIEW in submission 4ae3e758-440a-4bb2-82ae-a2c586e7088e. Proof: submission-complete.png and submission-waiting-for-review.png. Details in Design/AppStore/2026-10-22/submission.json.
- User explicitly approved the export-compliance answer after auto-review rejection. Saved None of the algorithms listed, then added version to the same draft as the lifetime IAP and submitted both.
- All five locales now have localized keywords/release notes. Japanese/English keywords emphasize relevant features and do not use third-party app/brand names. Existing five sets of six screenshots retained. Review notes updated with purchase path and legacy-entitlement policy.
- IAP review screenshot uploaded: premium-review-en-local.png, actual UpgradeView on iPhone 16 Pro Max iOS18.5, Apple local StoreKit test product (JPY3900, English). Price and purchase button rendered and visually inspected. No real purchase was performed. Local test session code/framework dependency removed after capture; simple DEBUG-only direct purchase-screen entry retained. Uploaded Release64 does not contain this debug entry or test config.
- Release archive/upload succeeded, vendor SDK missing dSYM warnings non-blocking. Project build number aligned to 64. Existing auto-release-after-approval setting retained.
- No further action needed for submission. Await Apple review; do not resubmit or upload another build without a reason.
