# Pochi remains visible during workout selection

The room stays fixed while the exercise list scrolls beneath it. Selecting an exercise enables the fixed start button; target adjustments appear inline. Landscape places the room next to the controls.

Verified on iPhone SE (3rd generation), iOS 18.5 simulator:
- Select an exercise without opening a sheet.
- Scroll to the last exercise while Pochi and the start action stay visible.
- Edit the plank target from 5 to 6 seconds inline, retaining it when returning to selection.
- Rotate to landscape with the selection and start button intact.
- Start that plan with Pochi still visible; countdown reaches automatic rest.
- Discard the test session without saving a workout.

Screenshots:
- `selection-se.png`: selected pushup, fixed Pochi and start button.
- `scrolled-se.png`: list scrolled to the bottom.
- `landscape-se.png`: side-by-side selection layout.

Build: Debug app/widget simulator build passed; `.build/visible-pochi-start-build.log` has no diagnostics. No App Store submission.
