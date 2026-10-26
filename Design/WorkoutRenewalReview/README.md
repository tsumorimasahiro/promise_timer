# Workout-only renewal — 2026-10-24

- Removed the previous-habits section and old reading/study/home/hobby landscape and collection views. The active catalog, calendar, weekly summary, timed sessions and album achievements now contain strength training only.
- Added a one-time migration of active preset/log/session stores. Strength records retain their identity, timestamps, durations and session IDs. Non-training sessions stop; accounts with only legacy habits get the strength starter exercise. Fresh installs still see onboarding. An internal pre-migration recovery copy is kept, with no legacy product UI.
- The room now uses the exercise environment; reading stories are no longer discovered or shown in the album. Saved user photos remain. Existing body progression and understated presentation are unchanged.
- Compatibility classification and storage model names remain internal so the migration can identify old workouts. This is not a new app/bundle identity and does not reset purchases.

## Checks

- Debug Simulator app/widget build passed without diagnostics: `.build/workout-renewal-build.log`.
- WorkoutMigrationRegression, StrengthRegression and MemoryRegression passed. Memory coverage now includes exclusion of legacy reading stories while preserving exercise memories and chosen photos.
- Updated the existing iPhone 16 Pro Max / iOS 18.5 simulator that contained reading, water and strength data. Home's record sheet shows only strength with its completion retained. Calendar shows one strength record on October 24 with its existing 20-second duration; no reading/water entries or previous-habits section.
- Evidence: `records-after-upgrade.png`. No physical-device test or App Store upload/submission in this task.
