# Home and workout refinement — 2026-10-24

- `home-pro-max.png`: final home with larger Pochi and compact exercise tiles (the 5-second plank is an existing simulator test preference; default remains 30 seconds).
- `exercise-icons.png`: all 11 code-native pixel icons rendered from production data by `scripts/render_workout_icons.swift`.
- `pushup-0.png` … `pushup-3.png`: running exercise alternates between high/low positions. The head moves 19 screenshot pixels; paws stay grounded.
- `plank-0.png` … `plank-7.png`: timed exercise continues with subtle horizontal tremble. Sampled dog positions differ by up to 3 screenshot pixels.
- `sweat-00.png` … `sweat-15.png`: squat sequence on Pro Max. Cyan sweat pixels appear in frames 00, 07 and 15 and disappear in between. Each burst is removed after 0.9 seconds; start-to-start spacing is 5–8 seconds.

## Verified

- Debug iOS Simulator app/widget build succeeds without diagnostics (`.build/home-workout-build.log`).
- TogetherRegression: old planned set targets no longer end the session; recording after a completed set excludes unstarted sets, current rep sets default to their target, time sets contain actual elapsed seconds, and rest/relaunch/20-set record bounds remain valid.
- MemoryRegression: workout-only photo gate and history preservation pass.
- Five localization files pass lint; `git diff --check` passes.
- SE3 UI: setup has only reps/time; one completed pushup set saves as one set; 30-second plank automatically rests, survives relaunch, resumes the next set, and saves 30/30 seconds with a 2-set count. Records retain the captured workout photo.
- Pro Max UI: all eleven exercise tiles fit above the tab bar (custom add action remains scrollable). Squat start, rest and discard return the dog to its normal idle behavior.

The scene still respects system Reduce Motion. No real-device or App Store deployment was performed in this change.
