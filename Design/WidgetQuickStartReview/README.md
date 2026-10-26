# Widget quick-start review

The small widget opens the first recent exercise directly. The medium widget offers three saved exercises with pixel icons and reps/time; when a session exists, it offers a return action. Names, breed/coat and exercise plans use shared app-group settings. WidgetKit controls when timeline changes appear.

`medium-widget.png` is an actual SE3/iOS18.5 home-screen capture showing the chosen dog name and a saved 6-second plank target.

Verification:
- Tapped the small widget: squat starts directly with 10 reps.
- Tapped the medium widget after a simulator restart: the saved 6-second plank begins without an intervening picker or editor.
- Tapped squat while that plank awaited saving: the existing plank remains intact.
- Discarded both verification workouts without adding records.
- WidgetRegression, Debug app/widget builds, five locale files, app plist and whitespace validation pass.

The final simulator build uses ad-hoc signing so simulated app-group entitlements are present. The unsigned development installation had isolated preferences; its existing QA settings were backed up and restored into the simulator's shared group for realistic verification. No device data or App Store build was changed.
