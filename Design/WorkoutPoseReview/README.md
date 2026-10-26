# Canine workout pose review

Eight additional frames cover supine rest, half/full crunch, alternating dead bug, hip bridge and alternating bird dog. Dedicated belly-up faces are drawn with upward muzzles and lowered ears for each breed; paws remain bent and canine rather than human hands/feet.

- `canine-exercises.png`: new poses for all three breeds.
- `growth-stages.png` and breed atlases: generated growth-stage previews.
- `crunch-live.png`, `crunch-frame-1.png` through `crunch-frame-4.png`: earlier SE3 simulator captures, before the head-orientation correction. Refer to `canine-exercises.png` for the current poses.
- Generator: `scripts/render_workout_pose_review.swift`.

Validation: Debug simulator app/widget build, StrengthRegression (including all new frames across all breeds and growth stages), and live crunch cycle verification passed. The disposable UI session was ended without recording.

Latest refinement: five crunch levels now move the shoulders, forepaws and head together, with a slower return to the mat. `crunch-motion.gif` previews the updated cycle for all three breeds. The daily record UI now shows the workout values without the redundant together-duration line.

The latest redraw replaces all flipped/resampled heads with dedicated pixel maps and uses a rounder torso, tucked front paws and a smaller shoulder curl. The preview GIF reflects this design.
