# 犬種の見た目の調整（2026-10-22）

## 参照

形の検討に写真・イラストを使用。外部の画像をアプリへ取り込んだり、トレースした素材を配布したりせず、既存の32×32スプライト描画を修正。

- ポメラニアンのシルエット（実際にブラウザーで画像を表示して確認）: https://illustsozai.official.ec/items/79634008
- ダルメシアンの子犬イラスト（検索で提示されたCanvaのプレビューをブラウザーで表示して確認）: https://www.canva.com/ko_kr/graphics/s/puppy-illustration/
  - 画像: https://marketplace.canva.com/XVyWo/MAHBpuXVyWo/1/tl/canva-cute-dalmatian-puppy-illustration-MAHBpuXVyWo.png
- 犬種の特徴: https://www.akc.org/dog-breeds/pomeranian/
- 犬種の特徴/斑点: https://www.akc.org/dog-breeds/dalmatian/ および https://www.akc.org/expert-advice/dog-breeding/what-makes-dalmatian-spots/

## 設計

- ポメラニアン: 頬から胸まで連続した毛のふくらみ、小さな耳、幅のある胴体、背中に乗る大きな巻き尾。毛先は同じピクセル密度の段差で表現し、滑らかな補間や色のグラデーションは追加しない。
- ダルメシアン: 丸い額と口元、頬に沿って垂れる先細りの耳、胴を少し長くして見える範囲を確保、大小の丸い斑点。四角い斑点と長方形の耳の印象を弱める。
- 全フレームは同じ頭/耳/斑点の定義を再利用し、目・鼻を顔とまとめて変形。待機、まばたき、首かしげ、食事、睡眠にも同じ特徴を適用。
- 3犬種×3色と首輪なしを維持。保存キー、購入仕様、ユーザーの履歴や写真は変更しない。

## 確認素材

- `nine-coats.png`: 9色の見本。画像を実際に開いて確認。
- `BeforeBreedRefinement/nine-coats.png`: 今回変更前の見本。
- `../MotionReview/pomeranian-frames.png` と `dalmatian-frames.png`: 全32ポーズを開いて確認し、耳と胴体/尻尾の形を再調整。
- `../MotionReview/*-motion.gif`: 動きのフレーム見本。実アプリの録画ではない。

実機・シミュレーターの操作とゲーム内移動の見た目は未確認。

## 横顔を子犬らしく再調整

追加で表示して参照したイラスト（外部素材の導入・トレースなし）:

- ポメラニアン: https://www.clipartkey.com/view/wJobwo_pomeranian-clipart/
- ダルメシアン: https://www.pngwing.com/en/free-png-hlxzb

丸い瞳の光、短い足、頬と胸の丸みを参考に独自の32px描画を調整。ポメは暖色の輪郭と毛から少し見える足、ダルは短い鼻先と丸い頬、垂れ耳に変更。全ポーズで顔パーツを共有し、3色にも反映。`../ProfileReview/cute-profiles.png` は実コードからの描画見本。
