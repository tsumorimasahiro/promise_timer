# 一緒に取り組む時間の回帰確認

```sh
xcrun swiftc -module-cache-path .build/ModelTestCache promise_timer/HabitModels.swift promise_timer/PochiTogetherSession.swift promise_timer/PochiWorldModels.swift promise_timer/PochiLifeHabits.swift promise_timer/PochiDailyRoutine.swift Tests/TogetherRegression/main.swift -o .build/together-regression
.build/together-regression
```

アプリと同じモデルを使用。開始状態・休憩状態のJSON復元、バックグラウンド相当の経過、日付またぎ、時計の巻き戻り、休憩時間の除外、同日の時間合算、保存再試行の重複防止、他の日・他の習慣の保持、旧記録の互換性、時間表示、活動別の付き添い動作を確認します。

実機の時計変更、クラッシュ中のOSによるディスク書き込み保証、SpriteKitの実描画はこのテストの範囲外です。

筋トレのセット追加分: 秒数指定のカウントダウン、休憩と再起動の復元、バックグラウンドで締切を超えた時間の上限、セット間の休憩除外、途中セットだけの秒数提案、セット別実績、予定回数の初期値を検証します。

2026-10-24: 予定セット数による終了を廃止。旧設定のセット数を超えて続けられること、休憩中に未着手のセットを提案しないこと、回数種目は実行中の1セットだけ既定回数を提案すること、20セットの保存上限と復元も確認します。
