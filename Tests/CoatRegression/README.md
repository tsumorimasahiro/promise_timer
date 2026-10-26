# 犬種別の毛色・保存互換性

本体の描画処理から9種類×32フレームを生成します。設定の確認はUUID付きの専用UserDefaults suiteだけを使用し、終了時にそのテストsuiteだけを削除します。実ユーザーの保存先には触れません。

```sh
xcrun swiftc -module-cache-path .build/ModelTestCache promise_timer/HabitModels.swift promise_timer/PochiSpriteGeometry.swift promise_timer/PochiBreedSprites.swift promise_timer/PochiMotionSprites.swift promise_timer/PochiCoat.swift Tests/CoatRegression/main.swift -o .build/coat-regression
.build/coat-regression
```

検証: 各犬種3パレットの違い、全288フレームの寸法/透明度/輪郭の形/目/口/クリーム模様の保持（ポメの毛の輪郭色は毛色に追従）、旧kinako/milk設定、犬種別保存、再読込、未知の値の安全な初期値、旧首輪/チャーム設定を消さないこと。

素材の見本とウィジェット用の32px画像の再生成:

```sh
xcrun swiftc -module-cache-path .build/ModelTestCache promise_timer/HabitModels.swift promise_timer/PochiSpriteGeometry.swift promise_timer/PochiBreedSprites.swift promise_timer/PochiMotionSprites.swift promise_timer/PochiCoat.swift scripts/render_coat_review.swift -o .build/render-coats
.build/render-coats
```

見本: `Design/CoatReview/nine-coats.png`。9枚の全32フレームのアトラスも同フォルダに保存。これは実際の描画素材の確認で、アプリ画面・シミュレーター操作の確認ではありません。
