# Strength training catalog

Run from the repository root:

```sh
xcrun swiftc -module-cache-path .build/ModelTestCache promise_timer/HabitModels.swift promise_timer/PochiWorldModels.swift promise_timer/PochiPromiseReaction.swift promise_timer/PochiWorkoutCatalog.swift promise_timer/PochiStrengthProgress.swift Tests/WorkoutCatalogRegression/main.swift -o .build/workout-catalog-regression
.build/workout-catalog-regression
```

Covers training-only starter choices, empty-selection fallback, preservation of selected exercises, custom exercise identity after persistence, growth from custom logs without presets, and preservation/exclusion of legacy non-training records. No user data is read or written.
