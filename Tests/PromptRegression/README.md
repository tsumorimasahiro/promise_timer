# Workout completion prompts

Run from the repository root:

```sh
xcrun swiftc -module-cache-path .build/ModelTestCache promise_timer/WorkoutPromptPolicy.swift Tests/PromptRegression/main.swift -o .build/prompt-regression
.build/prompt-regression
```

Verifies no first-use prompts, unique saved completions, three training days before prompts, review priority after five completions, a seven-day shared cooldown, ten additional completions and thirty days between premium offers, subscriber exclusion, and persistence. StoreKit decides whether to show the native review prompt; a request is not a guarantee of display. Premium offers also require available product information.
