# 保存データ互換性チェック

シミュレーターやユーザーのUserDefaultsを使わず、本体と同じFoundationモデルをコンパイルしてJSON互換性を確認します。

```sh
mkdir -p .build
xcrun swiftc -module-cache-path .build/ModelTestCache promise_timer/HabitModels.swift Tests/ModelRegression/main.swift -o .build/model-regression
.build/model-regression
```

検証対象は旧形式の省略フィールド、週目標の境界値、20件の多言語プリセット、0件の保存、削除済み習慣に対応する履歴、ISO8601日付の往復です。SwiftUIの操作、UserDefaultsへの書き込み、日付変更通知の配信はこのテストの対象外です。

追加検証: 反応キューの順序、同じ行動だけの集約・行動種類数による上限、重複ID抑止、取り消し、月の日付生成（うるう年・年越し・日曜/月曜始まり・東京/ロサンゼルスの夏時間）。SpriteKitでの再生・撮影や共有シート表示は実行時確認が別途必要です。
