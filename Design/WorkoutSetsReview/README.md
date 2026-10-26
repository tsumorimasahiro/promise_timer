# Strength workout renewal — 2026-10-24

Implemented 11 distinct basic exercises, editable repetition/time/set plans, named custom exercises, plan editing during onboarding, direct home exercise buttons and a compact uncropped dog room. Generic strength template, weekly targets and exercise color selection are absent from the active flow.

Timed sets pause at their deadline and require explicit start of the next set. Elapsed time excludes rests and is capped at the current deadline across background/relaunch. Results are prefilled, editable per set, persisted alongside existing history, and replay-safe. Only training captures become daily photos; backfill/idle days do not fabricate pictures.

All basic exercises select a dog movement. Core exercises tremble; active workouts show pixel sweat. Rest and idle resume normal dog behavior. Front-facing Shiba, Dalmatian and Pomeranian eyes/mouths were refined; corresponding widget frames regenerated. The app icon uses the exact puppy pushup-low sprite on opaque cream.

The latest request replaces proposed interstitial ads with the existing Premium purchase sheet. No new AdMob unit was created. Premium offers require 3 training days, 10 completions since the last offer, 30 days between offers, available product data and no active subscription. Native rating requests begin after 5 completions across 3 days and have a 180-day cooldown. Both share a 7-day cooldown and are considered only after a successful workout save and result-sheet dismissal. Onboarding, backfills, abandoned sessions and active workouts do not trigger prompts. Apple's system decides whether to display its rating dialog. Existing banners remain.

Validation:
- Debug iOS Simulator app/widget build succeeds; five locale files pass syntax checks.
- Together, Prompt, WorkoutCatalog, WorkoutMigration, Memory, Sprite and Strength regressions pass.
- Pro Max/iOS18.5: plan changed to 5 sec × 2 sets, both countdowns finish, next set requires a tap, unchanged values save as 5 / 5; persisted across reinstall/relaunch.
- Side plank: first 30-second set and partial 9-second second set saved as 30 / 9 with elapsed 00:39. Pause stops motion/sweat and time; resume synchronizes motion. Recorded photo contains the active workout with sweat. Direct exercise-card selection opens that exercise's settings.
- Source-rendered face review: ../FaceReview/front-refined.png; exact icon: ../IconPreview/training-app-icon-256.png.

No App Store upload, purchase, or production review submission. Premium/review cadence is verified with model tests; real StoreKit prompt display and purchases are OS/account dependent.

SE3/iOS18.5 onboarding preview also verified: all basics are prefilled, editing plank from 3 to 2 sets updates both the menu and final summary, and the continue/start buttons remain reachable on the small screen. `onboarding-basics-se.png` captures the edited defaults.
Settings preview on SE3 also confirms the introductory paragraph is gone. Both QA simulators were returned to the ordinary home after preview checks; the SE home shows the smaller room and directly accessible exercise buttons.
