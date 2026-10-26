# Calm daily routine regression

Compile and run the production Foundation routine without SpriteKit or user data:

```sh
xcrun swiftc -module-cache-path .build/ModelTestCache promise_timer/HabitModels.swift promise_timer/PochiWorldModels.swift promise_timer/PochiLifeHabits.swift promise_timer/PochiDailyRoutine.swift Tests/RoutineRegression/main.swift -o .build/routine-regression
.build/routine-regression
```

Checks morning/day/evening episodes, quiet nights, phase changes, calm follow-ups
after recorded activities, and the absence of props or training moves during idle
even with old reading/study/exercise progress. Active strength training remains available.
SpriteKit animation pacing and actual lifecycle interruptions require device or
simulator confirmation. MemoryRegression also checks time/context filtering of
pending special moments.
