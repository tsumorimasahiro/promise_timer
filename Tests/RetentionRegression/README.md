# Retention regression

Run from the project root:

```sh
xcrun swiftc -module-cache-path .build/ModelTestCache promise_timer/HabitModels.swift promise_timer/PochiWorldModels.swift promise_timer/PochiPromiseReaction.swift promise_timer/PochiWorkoutCatalog.swift promise_timer/PochiStrengthProgress.swift Tests/RetentionRegression/main.swift -o .build/retention-regression
.build/retention-regression
```

Checks calendar week boundaries, distinct training days, repetition/time separation, future and legacy non-workout exclusion, empty weeks, and growth milestones. Fixtures never read or write user records.
