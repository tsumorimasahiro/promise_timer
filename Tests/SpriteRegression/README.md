# 犬の顔・尻尾のフレーム検証

本体と同じ描画コードから3犬種×32フレームを生成します。SwiftUIやSpriteKitの起動、ユーザーデータへのアクセスはありません。

```sh
xcrun swiftc -module-cache-path .build/ModelTestCache promise_timer/HabitModels.swift promise_timer/PochiSpriteGeometry.swift promise_timer/PochiBreedSprites.swift promise_timer/PochiMotionSprites.swift Tests/SpriteRegression/main.swift -o .build/sprite-regression
.build/sprite-regression
```

検証対象:

- 128×256のアトラスと32×32のフレーム契約
- 96フレームで透明度が0/255のみ
- 犬の画素が8方向で一つにつながり、尻尾/足/不要な画素が孤立していない
- 尻尾の付け根が胴体にあり、振ったときに位置が変わらない
- まばたきで目の座標が変わらない
- 実際の目の画素が顔座標と一致し、古い目や余分な黒い画素が目の帯域に残らない
- 向きを変えても目の間隔が一定、鼻も同じ頭の変換に追従

出力を目視確認する場合:

```sh
xcrun swiftc -module-cache-path .build/ModelTestCache promise_timer/HabitModels.swift promise_timer/PochiSpriteGeometry.swift promise_timer/PochiBreedSprites.swift promise_timer/PochiMotionSprites.swift scripts/render_motion_review.swift -o .build/render-motion-review
.build/render-motion-review
```

`Design/MotionReview/`に各犬種の原寸アトラス、首輪のない全32フレームの一覧、GIFを出力します。GIFはフレーム描画のサンプルで、SpriteKitの移動・タップ・実際の画面録画ではありません。

向きの統一: 通常の横顔は目が1つ、こちらを見る/まばたき/首かしげ（12,13,14,29）は目が2つであることも検証します。横顔の鼻は口元の専用アンカー、正面は顔の中央のアンカーと一致することを確認します。目の探索範囲は顔の向きに合わせて耳や輪郭を除外します。

横顔と正面の整合: 犬種ごとの目の黒い画素とハイライトが、横顔・正面・左右の首かしげで一致することを追加確認。柴犬は共通の2pxの目、他の2犬種は共通の4pxの丸い目を使い、傾きで分断されないよう目全体を同じ変換に含めています。
