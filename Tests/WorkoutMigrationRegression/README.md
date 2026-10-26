# Workout-only upgrade

```sh
xcrun swiftc -module-cache-path .build/ModelTestCache promise_timer/HabitModels.swift promise_timer/PochiWorldModels.swift promise_timer/PochiPromiseReaction.swift promise_timer/PochiWorkoutCatalog.swift promise_timer/PochiTogetherSession.swift promise_timer/PochiWorkoutMigration.swift Tests/WorkoutMigrationRegression/main.swift -o .build/workout-migration-regression
.build/workout-migration-regression
```

Uses a disposable UUID UserDefaults suite. Covers mixed legacy/training data, deleted exercise history, preserved durations and session IDs, paused workout retention, removal of reading timers, an internal recovery copy, idempotence, legacy-only starter selection, intentional empty lists, fresh-install onboarding, and no partial writes on corrupt input. Existing progression keys are untouched.
