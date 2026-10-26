# Finish and save directly

Verified on the iPhone SE (3rd generation), iOS 18.5 simulator:
- Repetition workout: target reps appear with no elapsed clock. Finish and save returns to the exercise list with saved confirmation, without a result editor or intermediate set screen.
- Six-second plank: countdown stops and shows the finish/save button; the session remains unsaved until pressing it.
- Changing the profile name to こむぎ updates the home title to こむぎと筋トレ. The onboarding name field remains present in source.
- Switching from active training to records and back preserves training. `pushup-1.png` and `pushup-2.png` show the actual high/low poses after returning. `pushup-3.png` and `pushup-4.png` are additional consecutive frames.
- `timer-finished.png` shows the timer-complete state waiting for manual finish.

The final Debug app/widget build passed without diagnostics. TogetherRegression covers rep-only records without durations, daily session aggregation and retry deduplication. Five localization files and whitespace checks passed. This is simulator QA; no App Store upload.

Follow-up layout: the shared banner is now attached outside/below the TabView. The records navigation title uses inline mode to remove the empty large-title area. Core tremor bursts use balanced uneven offsets and a short pause, shared by plank, side plank, bird dog and dead bug; the sprite remains quadrupedal.

Final profile QA: changing the draft name and cancelling preserved the original home name; saving a different name updated it. The editor has Save and Cancel, and no separate breed-confirm button. Changes to coats are also drafts; the preview uses the selected draft coat.

`records-banner.png` confirms the actual AdMob test creative below the tabs and the reduced records-header spacing. `core-1.png` through `core-4.png` are consecutive frames from a 30-second side plank. That disposable QA session was discarded without recording. Final app/widget Debug build passed without diagnostics.
