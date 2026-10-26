# 筋トレ成長の回帰確認

プロジェクトのルートで実行します。

```sh
xcrun swiftc -module-cache-path .build/ModelTestCache promise_timer/HabitModels.swift promise_timer/PochiWorldModels.swift promise_timer/PochiLifeHabits.swift promise_timer/PochiDailyRoutine.swift promise_timer/PochiPromiseReaction.swift promise_timer/PochiStrengthProgress.swift promise_timer/PochiSpriteGeometry.swift promise_timer/PochiBreedSprites.swift promise_timer/PochiMotionSprites.swift promise_timer/PochiMuscleSprites.swift promise_timer/PochiCoat.swift Tests/StrengthRegression/main.swift -o .build/strength-regression
.build/strength-regression
```

筋トレだけの集計、同日重複防止、3・7・14・30日の成長、休息・記録削除後の成長保持、タイムゾーン変更時の再集計、保存復元、既存の多言語記録、姿の選択制限、動作の解放を確認します。画像は3犬種×5段階を生成し、初期の32ポーズの完全一致、目の保持、毛色適用後の寸法も確認します。

SpriteKitの動作と保存を含む画面確認の記録は `Design/MuscleReview/README.md` にあります。

四つ足の筋トレ表現について、体の面積が元の118%以内、足先を拡大しない、座る・寝る姿が変わらない、運動中も水平な体形と前後の接地を保つことを全犬種・全段階で確認します。腕立て・スクワット・おもちゃの持ち上げの絵が実際に変わることも検証します。
