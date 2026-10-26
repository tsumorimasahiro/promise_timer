# Strength onboarding review — 2026-10-24

Update: growth is now deliberately undisclosed. Removed milestone copy, growth preview, home countdown, profile stage chooser, and growth references in Settings/forms/Premium/widget. Automatic progression remains. `06-ready-without-growth-ja.png` shows the current final onboarding step; earlier screenshots and the original description below document the prior iteration. The updated app/widget build and localization lint passed; onboarding was reviewed again on the same SE3 simulator.

The app now introduces Pochi as a strength training companion. New installs choose from strength training, squats, pushups, dumbbells, or a custom exercise. The three steps introduce Pochi, choose exercises, and explain elapsed timing and cumulative growth. Rest does not remove growth.

Home actions, add/edit forms, weekly summary, profile previews, Settings guidance, Premium free-feature copy, and widget metadata now use strength training language. Japanese, English, Korean, Simplified Chinese, and Traditional Chinese strings were updated. Existing non-training records remain available under the collapsed previous-habits section and in history; no saved data is deleted.

## Verification

- Debug Simulator app/widget build passed with no diagnostics: `.build/workout-onboarding-build.log`.
- WorkoutCatalogRegression and ReactionRegression passed. All ten app/widget localization files passed plist lint; new translated format placeholders were checked.
- Fresh iPhone SE (3rd generation), iOS 18.5 simulator, Japanese: visually checked all three onboarding steps, template chooser, and Settings on the smaller screen.
- Used the trial Pochi reaction, deselected the default strength item, selected only pushups, and completed onboarding. Main home action started pushups with elapsed time. Completing an eight-second session raised growth from zero to one day.
- Installed the final build over that test install and relaunched: growth remained one day; template picker showed pushups already registered and offered only the four training templates.
- Screenshots: `01-meet-ja.png`, `02-choose-ja.png`, `03-ready-ja.png`, `04-templates-ja.png`, `05-settings-ja.png`.

## Limits

Actual widget presentation, physical-device behavior, and visual layouts in the other four languages were not checked in this task. No App Store upload or submission was performed. Screenshots are test simulator data.
