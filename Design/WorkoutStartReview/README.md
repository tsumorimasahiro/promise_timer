# Workout start flow — 2026-10-24

Home → Start a workout → Select an exercise → Start.

`home-se.png` shows the single home entry point and today's completed exercises. `selection-se.png` shows the selected tile plus the fixed start panel. Reps/time editing is optional; naming/icon editing is in the selected exercise menu and custom addition is below the grid.

Verified on iOS 18.5 SE3 and iPhone 16 Pro Max simulators:
- No selection: start disabled; selection has border/checkmark and accessibility selected trait.
- Default pushup target starts directly from selection without an extra form.
- Changing plank from 30 to 5 seconds updates the selection, survives choosing another exercise and coming back, and starts a 5-second timer that automatically rests.
- The final 420-point settings sheet shows the input on SE3 without requiring expansion. Cancelling returns to the selected exercise.
- Debug app/widget build succeeds with no diagnostics. Five locale files pass lint; whitespace check passes.

The 5-second plank remaining in the test simulators is a test preference; the default is still 30 seconds. No real-device or App Store deployment was performed.
