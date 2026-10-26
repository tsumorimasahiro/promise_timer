# 筋トレで育つぽち — 2026-10-24

## 実装

- ホームの「ぽちと筋トレ」から時間制限なしで開始。経過時間を計測し、休憩・再開・完了できる。
- 筋トレを達成した累計日数で成長。0・3・7・14・30日の5段階。連続日数ではなく、休んでも減らない。
- 同日の複数種目や繰り返しは成長1日分。既存の筋トレ記録も反映。散歩・ランニング・ストレッチは対象外。
- 腕立て・スクワットから始め、3日でおもちゃをくわえるダンベル風の動き、7日でしっぽを振る得意げな姿、14日で得意げな歩きが増える。
- プロフィールで自動成長、または獲得済みの姿を選択。選んだ姿に対応する動作を使用する。
- 全3犬種・3毛色に対応。ウィジェットも同じ体格を描画する。

## 確認結果

- Debug Simulatorビルド成功（アプリ・ウィジェット）。Model / Reaction / Routine / Together / Strength / Sprite回帰確認成功。
- Sprite回帰の正面顔の期待値は、既存の10月22日の顔修正（目のハイライト、間隔、鼻位置）に合わせて更新。
- iPhone 16 Pro Max / iOS 18.5で開始、経過時間、完了、1日目の表示、同日の2回目が成長を増やさないこと、再起動後の1日目保持を確認。
- プロフィールで次の姿まで2日、未獲得の姿が選択不可であることを確認。
- DEBUG専用の30日目プレビューで実際のSpriteKit描画を確認。プレビューは成長の保存データを変更しない。
- `home-day1.png`: 再起動後の実際のホーム。
- `growth-stages.png`: アプリと同じ画像生成処理を使った3犬種・5段階の比較。各段階の通常姿と四つ足の腕立てを並べた資料。
- `canine-exercises.png`: 最大成長時の全8トレーニングポーズを3犬種で比較。
- `*-stage-*.png`: 40ポーズの画像シート。

実機、実際のホーム画面上のウィジェット、新規成長機能のReleaseビルドは今回未確認。App Storeへのアップロード・審査提出なし。

## 比較画像の再生成

```sh
xcrun swiftc -module-cache-path .build/ModelTestCache promise_timer/HabitModels.swift promise_timer/PochiWorldModels.swift promise_timer/PochiPromiseReaction.swift promise_timer/PochiStrengthProgress.swift promise_timer/PochiSpriteGeometry.swift promise_timer/PochiBreedSprites.swift promise_timer/PochiMotionSprites.swift promise_timer/PochiMuscleSprites.swift scripts/render_muscle_review.swift -o .build/render-muscle-review
.build/render-muscle-review
```

## 四つ足への修正（同日）

- ユーザーの希望に合わせて、二足で立つポーズ、人の腕、力こぶ、腹筋の線を撤去。旧 `mature-preview.png` は修正前の記録。
- 新しい8ポーズはすべて通常の横向きの犬がベース。腕立ては前脚、スクワットは後ろ脚を沈める。ダンベル風のおもちゃは口でくわえて上下。達成ポーズもしっぽを振る動きに変更。
- 肩・胸・後ろ脚の輪郭を少しずつ厚くする成長に変更。足先を大きくせず、足の間の空間と元の顔を保持。座る・寝る姿は元の絵を保つ。
- Strength回帰に体の面積上限、足先の不変性、各運動の水平な体形・前後の足の接地・運動ごとのポーズ差を追加。3犬種×5段階で成功。Routine/Together回帰も成功。
- 修正版のDebug Simulatorアプリ・ウィジェットのビルド成功。iPhone 16 Pro Max / iOS 18.5のDEBUGプレビューで制作時と同じ動作を個別確認。
