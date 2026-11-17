# Workout acquisition improvements — 2026-11-11

Implements the requested improvements 1–5. The separate promotional website (item 6) is excluded. Public App Store metadata, uploads, and social posts have not been changed in this work; the app's version and build numbers are unchanged.

## Changes

1. **Store screenshots:** 25 images across Japanese, English, Korean, Simplified Chinese, and Traditional Chinese. The sequence shows a workout companion, a running plank timer, saved exercise records, sharing a memory, and personalization. Hero images use push-ups. See the [asset README](../AppStore/2026-11-11/README.md), [Japanese contact sheet](../AppStore/2026-11-11/contact-ja.png), and [render manifest](../AppStore/2026-11-11/render-manifest.json).
2. **Real-app video:** the user's preference for more visible movement is reflected in a push-up-led sequence: repeated high/low poses, saving the workout, then seated rest. Final outputs are the [20-second App Store preview](../AppStore/2026-11-11/video/appstore-ja-20s.mp4) and [12-second social video](../AppStore/2026-11-11/video/social-ja-12s.mp4).
3. **Sharing:** a saved workout photo can be shared with a localized invitation, the app's formal name, and `https://apps.apple.com/app/id6760613210`. Turning off the invitation/link option shares only the image. Exercise details remain optional and off by default. A successful workout exposes an optional share action when a real saved photo is available; the share sheet snapshots that photo.
4. **Review requests:** eligibility no longer depends on `bannerEligible`, so Premium users and users without available ads can reach the existing review policy. The existing completion/day thresholds and cooldowns remain. StoreKit determines whether a requested rating prompt actually appears.
5. **First workout:** the opening screen can start a real five-repetition squat session without stepping through menu setup. Name/coat editing is optional, and the existing setup route remains available. The five-repetition introduction is a session snapshot; saved/default exercise targets are preserved. Ad preparation is deferred until a subsequent launch after a completed workout, rather than starting during the first-workout flow.

All new user-facing copy is localized in the app's five languages. Existing exercise records and the standard exercise catalog are retained.

## Video provenance and checks

The final movies use the actual simulator recording `../AppStore/2026-11-11/video/raw-pushups.mp4`. The complete UI is aspect-fitted into the canvas. Editing adds captions and a background outside that UI; it does not redraw controls, crop the source UI, or change playback speed. Audio is omitted.

| Output | Size | Duration | Frames | Encoding |
| --- | --- | --- | --- | --- |
| App Store | 886 × 1920 | 20 seconds | 600 | H.264, 30 fps, no audio |
| Social | 1080 × 1920 | 12 seconds | 360 | H.264, 30 fps, no audio |

The encoder target is 10 Mbps; the measured VBR averages are approximately 0.59 Mbps and 0.61 Mbps for this low-motion screen recording. Dimensions, duration, codec, and absence of audio were checked after export. Frame inspection covered repeated push-up poses, caption boundaries, the saved-home transition, and seated rest. No confirmation dialog is present in the selected ranges.

- [App Store frame contact sheet](../AppStore/2026-11-11/video/pushups-appstore-review/contact.png)
- [Social frame contact sheet](../AppStore/2026-11-11/video/pushups-social-review/contact.png)
- [Video source hashes, edit ranges, and metadata](../AppStore/2026-11-11/video/render-manifest.json)
- [Optional Japanese low-pose hero candidate](../AppStore/2026-11-11/raw/ja-hero-pushup-low-candidate.png), extracted at 3 seconds at the original 1320 × 2868 resolution

The earlier plank source `video/raw-workout.mp4` is retained for provenance. The final MP4 filenames above contain the push-up version. Older `video/appstore-review` and `video/social-review` contact sheets refer to the superseded plank edit; use the `pushups-*` review folders for the final movies.

The reusable export script is [render_growth_videos.swift](../../scripts/render_growth_videos.swift). Its `--help` documents input paths and the three source ranges. The screenshot compositor and capture provenance are documented in the asset README.

## App verification

The following model regressions passed during integration:

- [WorkoutCatalogRegression](../../Tests/WorkoutCatalogRegression/README.md): the five-repetition introduction and preservation of saved/default targets, alongside existing catalog coverage.
- [PromptRegression](../../Tests/PromptRegression/README.md): completion/day thresholds, cooldowns, Premium handling, and persistence.
- [MemoryRegression](../../Tests/MemoryRegression/README.md): workout-only photos, date boundaries, persistence, and failed-write protection.
- [TogetherRegression](../../Tests/TogetherRegression/README.md): workout/session recording, restoration, and compatibility.

Final Debug simulator and Release device app/widget builds passed, including both final layout adjustments, with no warnings or errors. Logs are `.build/growth-final-debug-build.log` and `.build/growth-release-build.log`. Localization validation and whitespace checks passed.

Existing real-simulator evidence:

| Image | Evidence |
| --- | --- |
| [01-onboarding-ja.png](01-onboarding-ja.png) | Opening screen with the immediate five-repetition entry |
| [02-first-workout-ja.png](02-first-workout-ja.png) | First workout in progress |
| [03-native-share-ja.png](03-native-share-ja.png) | Native sharing UI opened from the app |
| [04-complete-ja.png](04-complete-ja.png) | Recorded workout and the optional sharing entry |
| [05-ipad-onboarding-ja.png](05-ipad-onboarding-ja.png) | Final iPad introduction with the complete dog visible |

## UI verification scope

The iPhone simulator passed the real first-workout flow (five squats, save, normal ten-repetition target retained), the completed-workout share entry, and native sharing with the invitation/link on and off. Native sharing was opened and cancelled; no message was sent. All five localized sharing screens were inspected. The iPad passed the first-workout start/save flow, and its final introductory `compact: true` scene was visually checked with the complete dog visible.

The final shared-card change removes a fixed portrait photo height so wide workout photos retain their natural aspect ratio. This last layout change passed both builds, but a fresh UI check and five replacement captures could not be completed: Simulator reported insufficient process resources (`maxUserProcs: 1333`), followed by repeated Device Hub automation timeouts. The delivered five sharing screenshots are real captures from immediately before this spacing-only adjustment; their invitation text, URL, toggles, and sharing behavior match the implementation. Small-iPhone and iPad native-share checks remain unverified. No app-code deadlock was identified in the read-only review or sampled process; this does not establish a completed device check.

No physical-device purchase, public review submission, store-media upload, or social posting is established by these checks. Third-party share targets may accept different combinations of image, text, and URL.

## Submission preparation follow-up

On November 11, the final iPad sharing flow was verified on iPadOS 18.5 with the same functional Debug source: the invitation/link share sheet and image-only share sheet both opened and cancelled back to the editor. The final natural photo aspect ratio was also visually checked. See [iPad native-share evidence](06-ipad-native-share-ja.png). This resolves the iPad sharing limitation above; the small-iPhone check remains unverified. The signed 1.06 (66) archive then passed, but upload and submission require renewed Xcode/App Store Connect authentication. See [submission preparation](../AppStore/2026-11-11/submission-preparation.json).
