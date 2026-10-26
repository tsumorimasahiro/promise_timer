# 約束と犬の世界の状態検証

実際のアプリと同じFoundationモデルをコンパイルします。UserDefaults・実ユーザーの履歴・通知・外部サービスにはアクセスしません。

```sh
xcrun swiftc -module-cache-path .build/ModelTestCache promise_timer/HabitModels.swift promise_timer/PochiWorldModels.swift Tests/WorldRegression/main.swift -o .build/world-regression
.build/world-regression
```

対象: 日/週の期限、対象曜日、部分期間の除外、未達3日→達成→取消、複数テーマと表示枠の固定、約束削除/テーマと頻度の編集、初回導入、長期未起動、重複/未来の履歴、保存往復、ローカル分類、時差移動、夏時間の開始/終了、時計巻き戻し、深夜/朝/昼/夜の判定。

既存の保存データ・反応キュー・カレンダーの互換性は `Tests/ModelRegression` も実行します。

描画素材の確認画像を再生成する場合:

```sh
xcrun swiftc -module-cache-path .build/ModelTestCache promise_timer/HabitModels.swift promise_timer/PochiWorldModels.swift promise_timer/PochiSpriteGeometry.swift promise_timer/PochiBreedSprites.swift promise_timer/PochiMotionSprites.swift promise_timer/PochiWorldArtwork.swift scripts/render_world_preview.swift -o .build/render-world-preview
.build/render-world-preview
```

出力は `Design/WorldPreview/habit-world.png`。これは素材と状態の組み合わせであり、SwiftUI/SpriteKitを実行したスクリーンショットではありません。シミュレーター上の操作、実際のアニメーション、ライフサイクル通知の実配信は別途確認が必要です。
