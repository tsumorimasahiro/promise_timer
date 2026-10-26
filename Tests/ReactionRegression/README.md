# Promise reactions

```sh
xcrun swiftc -module-cache-path .build/ModelTestCache promise_timer/HabitModels.swift promise_timer/PochiWorldModels.swift promise_timer/PochiLifeHabits.swift promise_timer/PochiDailyRoutine.swift promise_timer/PochiPromiseReaction.swift Tests/ReactionRegression/main.swift -o .build/reaction-regression
.build/reaction-regression
```

Uses the production Foundation classifier and routine. Covers 29 built-in IDs,
22 custom/multilingual names and icon fallbacks, rest versus sleep, stretch versus
exercise, plant watering versus drinking, long-term learning families and a calm
follow-up after walking. No user data is read or written.

ModelRegression covers coalescing matching reactions, preserving different
activities, duplicate IDs, cancellation, and the finite activity-kind bound.
Actual SpriteKit playback, bubble artwork, reaction interruption and paused-tab
resume require simulator/device confirmation.
