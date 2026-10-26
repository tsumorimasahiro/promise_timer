# ぽちログ UI 改善 進捗

最終更新: 2026-10-21

## 作業方針

シミュレーターは操作せず、既存コードの調査、静的レビュー、iOS Simulator SDK 向けビルドで検証する。視覚確認していない画面は確認済みと扱わない。既存の習慣・履歴・プロフィール・オンボーディング状態の保存形式は維持する。

## 画面・構成の調査

- `ContentView.swift` にタブ構成、ホーム、履歴、オンボーディング、プロフィール編集、習慣の追加・編集、記録追加、カレンダー、履歴一覧、SpriteKit の部屋表示を実装。
- `PochiPixelUI.swift` にPixelMplusフォント、ドットアイコン、共通ボタン、入力欄を実装。共通色は `ContentView.swift` のColor拡張。
- `Subscription/SettingsView.swift`、`UpgradeView.swift`、`PaywallSheet.swift` に設定と課金関連画面。
- Widget ターゲットは本体と App Group の保存データを共有。
- 習慣ログ・プリセットは App Group の UserDefaults に JSON 文字列で保存。プロフィール名・毛色・首輪・チャームも同じ App Group に保存。初回選択完了状態は既存の標準UserDefaultsを維持。
- SpriteKit の犬部屋は `PochiRoomView` 系で表示し、SwiftUI から行動状態を渡す。
- 日本語/英語/韓国語/簡体字/繁体字の `Localizable.strings` と M PLUS フォントライセンスを確認。

## 発見した優先課題

1. 修正済み: カレンダーの画像はみ出し。日付数字と共通Pixel肉球を表示する44pt高のセルへ変更。狭い端末では7列の横幅が44pt未満になるため、実機で選択しやすさの確認が必要。
2. 画面の実行時表示をシミュレーターで確認できないため、小画面・Dynamic Type・ダークモードの最終視覚確認は未実施。
3. `ContentView.swift` に複数画面が集約されている。大規模な分割は回帰リスクがあるため、今回は機能を保った小さな修正を優先。
4. 設定・プロフィール・課金等には Pixel 以外の標準フォントが一部残る。入力可読性やOS標準操作に必要な箇所は保持し、画面見出しや操作ラベルは共通スタイルに寄せる。

## この作業以前に反映済みの内容

- 3ステップの初回導線（ぽちと出会う・約束を選ぶ・開始）と初回選択状態の維持。
- ホームの大きな犬表示、コンパクトな今日の約束、Pixel UIパーツ。
- 設定・プロフィール・習慣編集・ログ追加のレトロUI調整。
- 犬の表示倍率と移動範囲の調整、日英韓中のローカライズ。
- M PLUS Pixel フォントとライセンスファイル。

## 今回の検証状況

- 履歴カレンダーは日付数字＋12ptのPixel肉球に統一。44ptの高さをボタン内部で確保し、選択状態をVoiceOverにも通知。履歴一覧の60ptアイコンを24ptに修正。
- 習慣アイコンの選択欄に、記号名ではなく意味が分かる習慣名をVoiceOverラベルとして追加。選択状態と操作ヒントも維持。
- iOS Simulator 向け generic `xcodebuild build` 成功（2026-10-21、署名なし、最終編集を含む）。成果物 `.build/DerivedData/Build/Products/Debug-iphonesimulator/promise_timer.app` を確認。
- `plutil -lint` は全ローカライズ文字列で成功済み。
- `git diff --check` は成功済み。
- コードから静的抽出できる `localizedText` / `NSLocalizedString` キーは英語・韓国語・簡体字・繁体字で欠落0件。
- Foundationの保存モデルを `HabitModels.swift` に分離。`Tests/ModelRegression/main.swift` を本体と同じモデルでコンパイルし、旧形式・週目標境界値・20件の多言語データ・0件・ISO8601履歴の互換性チェック成功。UserDefaults/UI操作自体のテストではない。
- シミュレーター画面、タップ操作、全画面スクリーンショットは今回未確認。

## 次の作業

1. 小さい/大きい端末での実画面、Dynamic Type、ダークモード、操作フローはシミュレーターが利用できる環境で確認。
2. 通知による日付更新、編集シートの遷移、犬の行動マッピングの実行時確認が残る。

## 再開手順

このファイルと `git status --short` を確認する。シミュレーター操作はユーザーが可能と伝えるまで行わない。ビルド先は `generic/platform=iOS Simulator`、署名は無効にする。既存の `.build/` や変更済みファイルを削除・リセットしない。

## 継続改善（2026-10-21）

- ホームの「編集」から全習慣一覧を開き、各行から既存の編集・削除画面へ遷移可能にした。達成済みの習慣も編集できる。シート終了後に編集画面を開く。
- 最後の習慣を削除してもオンボーディングを再表示しない。空配列 `[]` を既存JSON形式で保存・復元し、プロフィール・達成履歴は維持。
- 保存済みプリセットの読込で登録上限による切り詰めを廃止。新規登録の上限判定は維持し、既存データが後続保存で失われる経路を防止。
- 日付変更、アプリ復帰、大きな時刻変更の通知で今日/週/カレンダーを更新。過去の日を見ていた場合は選択日を保持。
- オンボーディングの毛色と首輪を別の行にし、カスタム習慣を作った直後は追加した項目が見える一覧に切替。
- 習慣ボタンは2行に折り返し、編集アイコンの選択グリッドは最小44ptの可変列へ変更。追加時の見出しも「約束を追加」に変更。
- 入力欄に明示的な文字色/カーソル色を設定。編集画面の背景色も共通化。
- 最終変更を含む generic iOS Simulator SDK ビルド成功（exit 0、署名なし）。ログ: `.build/ui-continuation-final-build.log`。シミュレーターは起動・操作していない。
- 互換性チェック手順は `Tests/ModelRegression/README.md`。実ユーザーデータにはアクセスしない。

- カスタム習慣で選択したアイコンをホームにも反映。カスタム食事/運動アイコンを対応する犬の行動へ接続し、既存の組み込み習慣の行動判定は維持。

## 仕様レビューへの対応（2026-10-21）

### 実装した7項目

1. **記録が普段の仕草にも反映**: 直近7日・最大30件の履歴から生活傾向を復元し、直近12件のカテゴリで待機行動の抽選を調整。読書/勉強は本とくつろぐ、睡眠は昼寝、運動は歩行/伸びが出やすくなる。全行動は最初から利用可能で、親密度やレベルは使用しない。本は行動中だけ登場。データ追加保存は不要。
2. **初回の体験**: 出会う画面に「ためしに、ごはんをあげてみる」を追加。記録に残らないことを明示し、通常の犬の食事アニメーションを再利用。体験せず先に進むことも可能。
3. **全習慣とホーム表示の整理**: 「すべて（件数）」で全習慣一覧へ。記録・ホーム表示選択・編集を個別の操作に分離。ホームは最大4件、初期値は従来の先頭4件。表示選択は追加キー `pochiHomePresetIDs` のJSON配列として保存し、既存プリセットや履歴の形式は変更しない。
4. **連続記録の反応待ち**: 記録IDを持つ反応キューを追加。再生中の反応は完了まで維持し、待ちは最大3組。超過分は最後の喜びに集約。保存された記録自体は省略しない。取り消した記録の反応は待ち/再生中の両方で解除する。
5. **過去の記録へのアクセス**: 8週間固定から月カレンダーへ変更。前月/次月/今月の操作、月外の日付の薄い表示、折りたたみ式の今週の目標回数を追加。既存の日別履歴・追記・削除導線は維持。
6. **ぽちの撮影・シェア**: ホームのカメラからSpriteKitの現在の姿を撮影し、プレビューからOS標準シェアへ。約束名は初期状態で含めず、明示的にオンにした場合だけ追加。写真ライブラリの権限要求や自動投稿はない。以前の未接続のホーム用共有生成コードを整理。
7. **記録の取り消し**: 新規記録後8秒間、最後に追加した1件を取り消せる。既存の削除/保存処理を使い、反応キューも取り消す。時間経過後は既存の履歴画面から修正可能。

### 検証

- 最初の統合ビルド成功: `.build/spec-build.log`（generic iOS Simulator SDK、署名なし）。シミュレーターの起動/操作ではない。
- 本体と共通のFoundationモデルでテスト成功: 既存保存形式、週目標の境界、20件/多言語/空状態、削除済み習慣の履歴、反応キュー順序/集約/重複/取り消し、月カレンダー（うるう年・年越し・日曜/月曜始まり・東京/米国夏時間）。
- 全5言語の文字列ファイル構文チェック成功。追加文言も日本語・英語・韓国語・簡体字・繁体字に対応。
- 差分の空白エラーチェック成功。
- 最終調整（本の一時表示、月外日付、初期化前のプロフィール更新ガード）を含むビルド成功（exit 0）: `.build/spec-final-build.log`。

### 未検証・再開時の確認

- シミュレーターUI・スクリーンショットは未確認。実画面の完成度を点数で評価していない。
- 小画面/Dynamic Typeでホームと取り消し表示が収まること、全習慣から編集への遷移、ホーム表示選択の再起動復元を確認する。
- 急速な記録→反応の順序/集約→取り消し、バックグラウンド復帰、初回のお試しがログを増やさないことを実操作で確認する。
- 撮影画像の見え方、約束名オン/オフ後の共有内容、OS共有シートを実機または利用可能なシミュレーターで確認する。
- UserDefaultsの読み書きやSpriteKit再生はFoundationテストの対象外。保存形式の互換性検証と区別する。

- 翻訳補完を含む最終リソースビルドも成功（exit 0）: `.build/spec-localized-build.log`。全ローカライズの構文チェック、差分チェックを再実行し成功。

## アプリアイコン変更（2026-10-21）

- 内蔵画像生成ツールで柴犬スプライトを参考に、正面の顔を大きくしたドット絵アイコンを作成。クリーム背景、オレンジの毛、濃い茶の輪郭、緑の首輪。アプリ名は「ぽちログ」を維持。
- `promise_timer/Assets.xcassets/AppIcon.appiconset/pochi-pixel-icon.png` に保存し、Contents.jsonの参照を更新。1024×1024・アルファなしを確認、最終画像を目視確認。端末インストールとホーム画面の確認は未実施。
- 旧イラストは `Design/Archive/AppIcon-illustration-before-pixel.png` に退避。
- 生成方法: built-in image_gen、参照元はpochiPixelAtlas。最終修正プロンプト:

> Refine this exact app icon. Keep same front-facing Shiba face and green collar, same composition. Make true clean low-resolution pixel art: perfectly straight horizontal/vertical edges on uniform square pixel grid, absolutely NO wobbly edges, NO texture, NO shading, NO gradient, NO blur. Fill each color region uniformly with ONE solid RGB color: cream background, golden orange fur, ivory muzzle/inner ears, dark brown outline/eyes/nose, muted green collar. Preserve cute face, both ears and safe margins. Deliver exactly 1024 by 1024 pixels square opaque PNG app icon, no rounded corners, no border, no text.

- 生成結果は1254pxのため、組み込み時に1024pxへサイズ調整。厳密な32pxグリッドのスプライト流用ではなく、参照から生成したアイコン用イラスト。

## ダルメシアン・ポメラニアン／全部入り買い切り（2026-10-21）

### 実装

- `PochiBreed` を追加。保存キーは追加の `pochiBreed`、既存ユーザーは柴犬。名前・柴犬の毛色・首輪・チャーム・記録の保存形式は保持。
- `PochiBreedSprites.swift` にオリジナルのコード描画による32×32ピクセル・8フレームの2犬種を追加。歩行4、食事2、睡眠1、座り1を128×64アトラスにまとめ、SpriteKitの既存行動へ接続。nearest設定、輪郭は整数ピクセル。ダルメシアンの斑点/垂れ耳/長い脚、ポメラニアンの毛の輪郭/短い脚/巻き尾を描き分ける。
- プロフィールで犬種を選ぶと無料で動くプレビュー。食事/睡眠も試せる。「この犬種にする」で有料権限を確認して保存。試着だけでは実際の犬種を変更しない。毛色の既存設定は「柴犬の毛色」として保持。
- 購入画面を全部入り買い切り1商品へ変更。広告非表示・20件までの約束・追加2犬種・今後追加する犬種/着せ替えを案内。価格はStoreKitのdisplayPriceのみ使用し、固定の980円や無料体験表記はない。
- 商品ID: `promise_timer.premium.lifetime`。商品タイプ `.nonConsumable` のみ新規販売。未取得時は再読み込みとエラー案内を表示して購入ボタンは出さない。
- 既存 `promise_timer.monthly` / `promise_timer.yearly` は新規購入画面から除外するが、有効な購入権限は引き続き認識して広告/登録数/犬種を解放。既存契約中は重複購入を案内せず、契約管理リンクを表示。既存契約の自動解約や永久権限への変換は実行していない。
- 取引の検証・finish、更新監視、復元結果、保留/キャンセル/失敗の区別を実装。既存の `isSubscribed` キャッシュ/参照名は互換性のため残し、意味は「買い切りまたは有効な旧サブスクのプレミアム権限」とする。
- 新規文言は日本語・英語・韓国語・簡体字・繁体字を追加。

### 確認

- 最初の統合ビルド成功: `.build/breeds-build.log`。generic iOS Simulator SDK、署名なし。シミュレーター操作ではない。
- 実際のアトラス生成コードをMac向けにコンパイルし、画像を生成して目視確認。`.build/BreedPreview/dalmatian.png` / `pomeranian.png`。これはアプリ画面のスクリーンショットではない。
- 最終のスプライト/翻訳調整を含むビルド成功（exit 0）: `.build/breeds-final-build.log`。5言語の文字列構文・差分チェックも成功。最終アトラス画像を再生成して目視確認済み。
- 実際の購入・復元・返金・旧サブスク更新・広告消去・犬種の再起動復元は実行時未確認。

### 販売開始前に必要な外部設定

1. App Store Connectで `promise_timer.premium.lifetime` を「非消耗型」として作成。価格は未決定なのでストア側で決定する。ローカライズ/審査情報/購入説明を登録する。
2. SandboxまたはStoreKitテストで新規購入、キャンセル、承認待ち、復元、返金後、オフライン、旧サブスクの権限を確認する。
3. 現在の契約者数と旧月額/年額商品の状態を確認し、既存契約者の移行方針とストア側の新規販売停止を決める。アプリの変更だけでは既存の自動更新契約は停止しない。
4. 小画面を含むプロフィール/購入画面、各犬種のアニメーションと装飾位置を実機または利用可能なシミュレーターで確認する。App Storeへの提出は行っていない。

## 海外ブランド名 PupHabit（2026-10-21）

- 日本語の「ぽちログ」を保持し、英語・韓国語・簡体字・繁体字のアプリ表示名を `PupHabit` に統一。
- ウィジェット表示名、プレミアムの名称、共有画像のアプリ名、共有文のハッシュタグも海外向けをPupHabitへ更新。犬の名前Pochi/포치/波奇はアプリ名とは別なので保持。
- 共有画像の `ぽちログ` と編集画面の `色` の翻訳漏れを補完。
- 静的に抽出できるText/Button/Toggle/TextField等と翻訳関数の日本語リテラルは4外国語とも欠落0件。全アプリ/ウィジェットstringsの構文チェックと差分チェック成功。動的文言すべての網羅性や実際の文字切れはこのチェックで保証しない。
- 言語別の実画面確認・ネイティブによる翻訳レビューは未実施。App Store Connectのストア名/商品名/説明文は今回変更していない。表示の切替は国ではなくアプリの選択言語に従う。

## 犬の仕草・姿勢遷移の拡充（2026-10-21）

### 実装内容

- `PochiMotionSprites.swift` に全犬種共通の32フレーム契約を追加。既存の柴犬画像とコード描画の追加2犬種を基に、32×32ピクセルの各姿勢を128×256アトラスへまとめる。元の柴犬の向きを他犬種に合わせて正規化し、移動方向と顔の向きを統一。
- まばたき、耳を前/後へ動かす、尻尾の上下、こちらを見る、左右の首かしげ、脚を曲げる、伏せる、あくび（小/大）、寝息、伸び（途中/完了）、頭を下げて食べる、舌の動き、ジャンプ前/着地、座り中のまばたき、うとうと、目覚めのフレームを追加。
- 柴犬の元の座りフレームは立ち姿だったため、後ろ脚をたたんだ姿に変更。旧食事フレームに描かれていた食器を使わず、犬だけの食事姿勢を生成し、SpriteKitの一時食器だけが表示されるよう整理。
- 睡眠は「立つ→かがむ→座る→あくび→うとうと→伏せる→眠る→起きる」。読書/勉強は本のそばで座り・まばたき・うとうと。運動は前脚を伸ばす姿勢と歩行・ジャンプを組み合わせる。
- 首かしげ/伸び/寝息は、犬全体の回転や縦スケールで表現していた処理をフレーム描画に置換。ジャンプは予備動作と着地フレーム付き。
- 犬種別テンポ: ダルメシアンは軽快、ポメラニアンは短い歩行サイクル/小さめジャンプ、柴犬は標準。静かなまばたき・座り・耳・尻尾の行動を抽選で重くし、同じ行動の連続を避ける。
- タップで中央手前へ寄り、こちらを見て首をかしげ尻尾を振る。連打によるリアクションの再始動を抑止。記録反応は引き続き優先し、既存キュー/取り消しを保持。
- 食事/睡眠に応じて首輪・チャームの表示位置を調整。ジャンプ中断による高さの累積ずれを防止。画面非表示中はアプリ復帰通知でもシーンを再開しない。
- 保存形式・課金・翻訳文言の変更なし。

### 確認と制限

- ビルド成功: `.build/motion-build.log`、`.build/motion-final-build.log`。座り姿勢の最終調整を含む `.build/motion-release-check.log` も成功（exit 0、署名なし）。
- 実際のアトラス生成コードをMacでコンパイルし、全3犬種の32フレーム一覧を生成・目視確認。`.build/MotionPreview/{shiba,dalmatian,pomeranian}.png`。見つけた食事の食器重複、口の位置、座る姿勢を修正して再生成した。
- フレーム動作サンプルを `Design/MotionPreview/{shiba,dalmatian,pomeranian}.gif` に保存。これは描画フレームのサンプルであり、SpriteKitの移動や実アプリの録画ではない。
- `git diff --check` 成功。シミュレーター/実機での動作・最終レイアウト・操作の確認は未実施。
- 次の実行時確認: 睡眠中/ジャンプ中に記録、反応取り消し、連打、バックグラウンド復帰、犬種切替、首輪の位置、アトラスの切り出し向き、移動/行動のテンポ。

## 習慣仕様の精査・無料上限の撤廃（2026-10-21）

### 今回の変更（以前の上限仕様を更新）

- 無料6件/プレミアム20件の登録制限を撤廃。追加時/保存時の課金判定を除去し、どちらもアプリ側の件数上限なし。
- 初回設定の最大6件制限も除去。推奨「まずは1〜3こ」は維持するが、選択数でボタンを無効化しない。
- 初回0件選択で既定の3件が勝手に登録される処理を廃止。最終画面に「約束はあとから追加できます」と明示し、空配列を既存形式で保存。既存ユーザーの登録や記録は変更しない。
- 購入画面から「20個まで登録」を削除し、登録/記録が無料で上限なしであることを明示。設定のプレミアム説明を「広告なし・追加の犬種」に変更。
- 有料の価値は広告非表示・追加犬種・今後の着せ替え。ホームの最大4件表示は、登録上限ではなく画面を犬中心に保つための表示数として維持。残りは「すべて」から操作できる。
- 新しい文言は全5言語対応。旧上限の案内キーを本体の翻訳ファイルから整理。

### 習慣候補の精査結果（未変更の改善候補）

- 「28種類」は28個の選択候補。読書1ページ/10分、勉強1問/10分は同じ活動の目標違いであり、28個の異なる体験ではない。将来的には「活動を選ぶ→小さな目標を選ぶ」にまとめる余地がある。既存IDや履歴を統合・削除していない。
- おすすめは8件に絞られているが、テンプレート選択は初回画面が中心。ホームの追加画面でも既存テンプレートを選べる導線が改善候補。
- 通常の追加フォームは新規カテゴリをcareで保存する。初回のカスタム作成ではカテゴリ選択があるため、両方のフォームの設定項目を揃える余地がある。
- 水分も現在は食事アニメーションへ接続。飲水の専用行動や、家事・音楽などへの反応は未実装。現状で各28候補に専用の犬動作があるわけではない。
- 現状は1習慣につき1日1回の達成チェック。水の杯数/運動時間/読書ページ数を積算する方式ではない。数量追跡を無断で追加していない。

### 確認

- 全5言語のstrings構文チェック、差分チェック成功。
- 上限変数・上限による追加拒否・初回選択拒否・上限由来の購入シートを削除したことをコードで確認。
- generic iOS Simulator SDKビルド成功（exit 0、署名なし）: `.build/unlimited-habits-build.log`。
- 端末上での多数登録/初回0件/既存データ復元の実操作は未確認。保存スキーマは変更なし。

## 習慣選択・記録アイコンの改善（2026-10-21）

### 実装

- 通常の「新しい約束」にテンプレート選択を追加。既存28候補をカテゴリ別に選べ、名前・アイコン・色・週目標を編集してから保存できる。登録済みの同一IDは選択不可。
- 読書と勉強は活動を選んだ後に小さな目標（1ページ/10分、1問/10分）を選ぶ構成に変更。オンボーディングも共通の目標選択を利用。既存のIDと履歴は統合・削除しない。
- 通常の追加・編集にもカテゴリ選択を追加し、選択内容を既存モデルに保存。
- 靴、歯ブラシ、食器、深呼吸、準備リスト、語学、手紙、集中の8種類のオリジナルドットアイコンを追加し、対応する習慣へ接続。既存アイコンの幅不整合も修正。全31種類は8×8の同じドット密度、整数倍率・アンチエイリアスなしで描画する。
- 水分の記録は飲水アクションへ変更。既存の頭を下げる/舌を出すフレームを再利用し、青い水の食器、短い飲む動作、尻尾を振る流れを追加。終了後は食器を片付け通常状態へ戻る。
- 新規文言は日本語・英語・韓国語・簡体字・繁体字に追加。
- 無料の登録上限なしを維持。時間や数量の積算機能は追加せず、1日1回のチェックであることを目標選択に明示。保存形式は変更なし。

### 確認結果

- iOS Simulator SDKで最終ビルド成功（exit 0、署名なし）。ログ: `.build/templates-icons-final-build.log`。
- 全5言語のstrings構文チェック、`git diff --check`成功。
- ソースから全アイコンが8×8であることを確認。追加8種類をソースのビットマップから画像化して目視確認。`Design/IconPreview/habit-icons.png`は素材の確認画像であり、アプリのスクリーンショットではない。
- シミュレーター操作・実機操作は未実施。テンプレート選択から保存、目標選択の戻る操作、カスタムカテゴリ変更、飲水と取り消し/連続記録の実行時確認が残る。
- 旧既定ID `stretch` とテンプレート `exercise` は互換性のため維持。ユーザーが両方を追加した場合は別の約束として扱う。

## 続けた習慣がぽちの癖になる（2026-10-21）

### 仕様・実装

- 過去7日間の記録による一時的な動きの偏りを、保存済み全履歴の累計達成日数による仕草へ変更。
- `PochiLifeHabits`で全体の達成日数と行動別の達成日数を算出。同じ日・同じ行動は複数記録しても1日分。未来の記録は集計しない。連続日数や期限は使わないため、休んでも失われない。
- 読書/勉強3日: 本を開いて座り、うとうとする。運動3日: こちらを見て伸び、ジャンプして遊びに誘う。睡眠3日: 夜（20時〜翌6時）にあくびして眠る。セルフケア3日: 伸びて横になり、くつろぐ。各7日でその仕草が出やすくなる。
- 全体7日: 近くに来て横になりくつろぐ。14日: 駆け寄り、ジャンプと尻尾で喜ぶ。数値・レベル・ゲージ・課金制限は追加しない。
- 初日から歩行・座る・首かしげ・昼寝・ジャンプなど基本行動は利用可能。新しい仕草は既存の統一スプライトの連続動作で表現。お腹を上にする新規スプライトは今回追加していない。
- 習慣記録の反応を優先する既存キュー、画面非表示時の停止、一時アイテムの片付けを維持。
- 既存ユーザーの履歴も初回表示時から反映。保存形式の変更や新しいポイント保存は不要。記録を取り消し/削除した場合は実際の履歴に合わせて再計算。削除済みの標準テンプレートもIDから行動を解決する。削除済みカスタム習慣はカテゴリ情報が履歴にないため全体日数のみ対象。

### 静的確認・未確認事項

- 集計ロジックをSwiftUI/SpriteKitから分離。新規・既存履歴、日別重複、未来の日付除外、休止期間に依存しないことをコードでレビュー。
- 画面にレベル/親密度を追加していないこと、常設家具や保存データの初期化を追加していないことを確認。
- シミュレーター/実機での仕草のテンポ、3/7/14日境界での表示、夜間動作、連続記録による割り込みは未確認。今回新規テストの追加・実行はなし。
- generic iOS Simulator SDKビルド成功（exit 0、署名なし）: `.build/learned-habits-build.log`。`git diff --check`成功。実行画面の視覚確認とは区別する。

## 個性に応じた出来事・思い出アルバム（2026-10-21）

### 実装

- 読書/勉強・運動・睡眠の累計3/7/14日に対応する9種類の出来事を追加。同時に複数の個性を育てられ、犬種や性格を一つに固定しない。
- 読書: 本を気にする→いっしょに読書→本のそばで寝落ち。運動: ボール発見→遊びに誘う→得意なジャンプ。睡眠: クッション発見→眠る準備→安心して眠る。
- 出来事はホームの自律行動中に再生し、習慣記録による反応を優先。中断された未撮影の出来事は次の機会に再生。連続再生を避け45秒の間隔を設ける。通常の習慣由来の仕草も維持。
- 達成済みの出来事候補を新しい専用保存領域に永続化。オフライン・休止で失効せず、既存履歴からも発見。初めての場面をSpriteKitから撮影できたときに写真・犬の名前・撮影日を保存し、一度保存した出来事は重複保存しない。
- 「きろく」上部に「ぽちの思い出」入口を追加。写真・出来事名・日付を表示し、標準の共有シートから写真共有可能。習慣名は画像に含めない。
- 新しいドット絵ボールを既存のピクセル描画で作成。犬・本・クッションは共通資産を再利用。常設家具やゲージは追加しない。
- 日本語・英語・韓国語・簡体字・繁体字に新規文言を追加。

### 保存と保護

- Application Support/PochiMemories/ に写真PNGとarchive.jsonを保存。アーカイブは原子的に書き込み、既存習慣・記録・プロフィールの保存形式は変更しない。
- 写真書き込み後にアーカイブを保存。失敗時は出来事を完了扱いにせず、後で再試行。既存アーカイブが読めない場合は上書きせず保存エラーを表示する。
- 写真/出来事の保存は端末内のみ。外部送信はユーザーが共有操作を行った場合のみ。
- 今回は優先案の個性・出来事・アルバムを実装。子犬から成犬への見た目の成長、新規の腹見せスプライトは対象外。

### 検証と再開手順

- 全5言語のstrings構文、差分の空白エラーチェック成功。新規自動テストは追加/実行していない。
- シミュレーター/実機操作、写真の実際の描画内容、共有、再起動・中断時の実行確認は未実施。
- 再開時は3/7/14日相当のテスト用履歴で、9種類の再生・記録の割り込み・非表示/復帰・写真保存後の再起動・同じ出来事の重複防止・保存失敗時の表示・5言語の長いタイトルを確認する。
- 最終ビルド成功（exit 0、generic iOS Simulator SDK、署名なし）: `.build/memories-release-check.log`。初回のCombine import不足を修正して再ビルド済み。最終ログに警告/エラーなし。

## 「今日のできた」と思い出を日別にまとめる（2026-10-21）

### 実装

- 思い出アルバムを日付ごとの1カードに変更。実際の達成履歴を直接参照し、同日の約束名・ドットアイコン・チェックを写真の下に表示。追加・取り消し・履歴削除を反映し、別の達成データを複製保存しない。
- 今日の記録がある場合、ホームのSpriteKit画面を日別写真として自動保存。既にその日の写真があれば増やさない。写真がない過去の日には代わりの写真を作らず、記録と写真なし表示のみを掲載。
- 特別な出来事が同日にある場合は最新の出来事写真を主役にして、同日の出来事名も同じカードに表示。従来の出来事写真はストレージから削除しない。
- 写真なし・記録なしの状態を明示。通常写真だけが残り、記録も出来事もない日は一覧から非表示にする（写真自体は削除しない）。
- 共有プレビューで「できたことも写真に入れる」を選択可能。初期状態はオフ。オンの場合は日付・犬の名前・達成した約束とアイコンを合成。共有中に内容や選択が変わった場合、古い画像の共有リンクを隠して再生成。
- アルバム内の記録数は制限しない。共有画像のみ、極端に長い画像の生成を防ぐため30件を表示し、超過分は「ほかNこ」と明示する。
- 通常写真の保存フィールドdailyPhotosはOptionalで追加。従来のarchive.jsonに存在しなくても読める構成。習慣ログの保存形式と既存写真は維持。
- 夜をまたいだ撮影待ちは翌日の写真として保存しない。非表示時は既存のSpriteKit停止に従い、再表示時に今日の記録から再判定。
- 新規文言を日本語・英語・韓国語・簡体字・繁体字に追加。

### 確認と残作業

- 初回ビルド成功: `.build/daily-album-build.log`（generic iOS Simulator SDK、署名なし）。
- 全5言語のstrings構文とgit差分の空白チェック成功。日別集約・既存Optionalフィールド・共有の初期設定・古い共有画像の抑制を静的確認。
- 新規テスト追加/実行はなし。シミュレーター/実機での画面表示、PNG撮影、共有画像、日付変更・取り消し・ウィジェット記録の実行時確認は未実施。
- 次回は通常の1件→追加→取り消し、過去の追記、同日の特別な出来事、再起動後の写真、0件・多数件・長い名前、共有のオン/オフを実機で確認する。
- 翻訳を含めた最終ビルドも成功（exit 0）: `.build/daily-album-final-build.log`。

## だらけたぽちのアプリアイコン（2026-10-21）

- 内蔵image_genで半目・床にあごをつける姿・投げ出した前足・緑の首輪の柴犬アイコンを作成。1回修正し、余白と輪郭を調整。
- `Assets.xcassets/AppIcon.appiconset/pochi-pixel-icon.png` を差し替え。1024×1024、アルファなし。既存のContents.json参照を維持。
- 旧版は `Design/Archive/AppIcon-upright-before-lazy.png`、生成元は `Design/Archive/AppIcon-lazy-generated.png` に保存。
- 生成条件と評価: `Design/IconPreview/lazy-app-icon-prompt.txt`。生成画像はドット絵風だが、微細な陰影が残り厳密な等間隔ピクセルグリッドではない。
- 原寸および60pxプレビューを目視確認。小さくしても顔と前足を識別できる。実際のiPhoneホーム画面・角丸マスクでの表示は未確認。
- iOS Simulator SDKビルド成功（exit 0、署名なし）: `.build/lazy-app-icon-build.log`。端末へのインストールは今回未実施。

## アイコンをさらに粗く・可愛く調整（2026-10-21）

- ユーザーの指摘を受け、内蔵image_genで大きな丸顔・点の目・短い前足の寝そべり柴犬に再作成。半目と細かな足/毛の描写を取り除き、輪郭のドットを粗くした。
- 1024×1024・アルファなしで既存AppIcon参照に組み込み。旧版は `Design/Archive/AppIcon-lazy-before-chibi.png` に保管。
- 原寸と `Design/IconPreview/chibi-app-icon-60.png` を目視確認。生成条件は `Design/IconPreview/chibi-app-icon-prompt.txt`。厳密な24×24グリッドではなく、微細な色差を含む生成画像である点は維持して記録。
- 端末ホーム画面での表示確認は未実施。
- アイコン差し替え後のビルド成功（exit 0）: `.build/chibi-app-icon-build.log`。

## 2犬種の描き直し・分かりにくいドットUIの見直し（2026-10-22）

### 犬の見た目

- ダルメシアンは大きな丸い顔、垂れ耳、小さな脚、控えめな斑点の子犬に描き直し。ポメラニアンは丸い頬・胸毛・太めの胴・短い脚・ふわっとした尻尾に変更。
- 2犬種は同じ顔/模様を共有して32フレームを組み立てる方式へ変更。旧汎用の頭部移動による顔の崩れ、脚が離れて見える部分を修正。まばたき、歩行の足、尻尾、首かしげ、食事、伸び、座る、寝る、起きるのポーズを維持。
- 新しい頭の位置に首輪とチャームが追従するよう、頭の移動量と装着位置を共通化。柴犬の描画経路は維持。
- 画像生成素材は追加せず、既存のCoreGraphicsドット描画を編集。32×32、フラットな色、nearest表示のまま。
- `Design/BreedPreview/updated-breeds.png`: 実描画の待機/座る/睡眠を整数6倍で表示した比較用画像。`.build/MotionPreview/{dalmatian,pomeranian}.png`は全32フレーム、`Design/MotionPreview/{dalmatian,pomeranian}.gif`はフレーム動作サンプル。実アプリのスクリーンショット/録画ではない。

### アイコンとボタン

- 湯船、茶碗、本、歯ブラシ、皿、コップ、靴、語学、便箋、家、カレンダー、歯車、共有、掃除、写真、服、ゴミ箱など主要アイコンを16×16へ描き直し。分かりやすい空洞と輪郭を優先。ベッドアイコンを追加し、睡眠と休憩の見た目を区別。
- チェック等の小さい状態表示は8×8を維持。肉球は16×16と小表示の8×8の2種類を用意。32種類・33バリエーションの正方グリッドを確認。
- タブのホーム/きろく/設定のSVGを同じ絵柄へ更新。
- 初回と通常の習慣作成で同じ `PochiIconChoice` を使い、絵だけの選択欄から「読書」「水分」など文字とチェック付きの選択欄に変更。可変列で幅を確保。保存済みアイコンの文字列は変更しない。
- ホームの撮影/プロフィールに見えるラベルを追加。ホーム表示切替に「表示中/ホームに表示」、履歴のゴミ箱に「削除」を表示し、削除アイコンの色のコントラストも改善。タップ領域44pt以上を維持。
- 運動のキーrunが靴へ誤対応していた点、肉球がハートへ対応していた点を修正。
- 短い選択肢の名前を5言語で補完。習慣・記録・プロフィールの保存形式や課金の条件は変更なし。
- `Design/IconPreview/clear-icons-v2.png`: 現行ソースから作成し目視確認したアイコン一覧。

### 確認

- 初回と再調整後のSimulator SDKビルド成功。頭と首輪の追従まで含めたログ: `.build/breed-icons-accessories-build.log`（exit 0、署名なし、警告/エラーなし）。
- 全5言語のstrings構文チェック、アイコン選択ラベルの翻訳存在確認、アイコンのグリッド形状確認、git差分チェック成功。
- ネイティブ描画コードで32フレームの一覧を生成し目視確認、足や胸のつながりを再修正して再生成した。自動ロジックテストの追加/実行なし（変更対象は描画・UIのみ）。
- シミュレーターの実画面、タップ、Dynamic Type、長い翻訳での折り返し、首輪付きのアニメーションの実表示は未確認。次回はプロフィールで2犬種のご飯/睡眠、ホームの写真/プロフィール、初回と通常のアイコン選択、履歴の削除を小さいiPhoneで確認する。
- 5言語と日本語ラベル補完を含む最終ビルド成功（exit 0）: `.build/breed-ui-localized-final-build.log`。

## 現実の約束と犬の世界を連動（2026-10-22）

### 調査・実装方針

- 既存画面: 3段階のオンボーディング、犬中心のホーム、週/月/日別の記録とアルバム、約束の追加/編集、プロフィール、設定/プレミアム。既存のSpriteKit反応キュー、アトラス、ピクセルUIと保存データを活用。
- 達成履歴はapp groupのhabitLogsStoreにISO8601のHabitLog配列、約束はhabitPresetsStoreにHabitPreset配列。現状は週目標1〜7回であり、曜日指定/個別の締切時刻はUI/モデルに存在しない。
- 方針: 週7回は日ごとに翌日判定、週1〜6回は自由な週目標として週の終了時だけ不足を判定。登録/導入/変更した途中の日・週は対象外にし、完全に観察した期間のみ扱う。既存履歴を遡って散らかさない。
- 今回の新しい指示に合わせ、従来の家具なし方針を更新。登録したテーマに応じて小さな本棚・机・ボールのみを表示。犬のサイズとホームの大きなゲーム領域は維持。

### 状態モデル・保存

- `PochiWorldModels.swift`: ローカル分類、期限評価、部屋状態、累計成長と生活時間帯をSwiftUI/SpriteKitから分離。
- テーマはreading/cleaning/exercise/studying/sleeping/general。日本語・英語・韓国語・簡体字・繁体字のキーワード、標準テンプレートID、選んだアイコン、カテゴリで推定。明示的な名前の変更を旧IDより優先。分類不能はgeneral。
- 新規カスタム約束の初期アイコンを汎用のsparklesに変更し、未分類の自由入力がデフォルトの勉強アイコンだけで机に分類される問題を回避。
- `PochiWorldRuleStore.swift`: 新しい独立キーpochiWorldRules.v1に判定開始日・テーマ・頻度・時差/週開始設定だけを保存。習慣/ログの形式は変更しない。未知/破損したメタデータは上書きしない。
- 編集でテーマ/頻度が変わったとき、時差や週開始曜日が変わったときは新しい観察期間を開始する。約束削除でルールとオブジェクトを除外し、過去の達成ログは保持。
- 登録テーマの過去の達成履歴から散らかりを再計算。今日の未達は判定せず、未来のログも無視。同日同じ約束の重複は累計でも1回。長期間未起動でも最大3段階、日数はCalendarで算出して夏時間を考慮。
- 柔軟な週目標は週の途中に1回達成しただけで全目標達成にはならず、終了時に実際の不足分を判定。ただし新しい週の達成で過去の散らかりは片付く。
- 全体の床オブジェクトは最大3個。登録中テーマに枠と位置を割り当て、読書を片付けた瞬間に別のゴミが増えたり移動したりすることを防止。
- 履歴は一度グループ化して評価し、約束ごとに全ログを走査しない。部屋のテクスチャはテーマ/散らかりが実際に変わったときだけ作り直す。

### 描画・犬の動作

- `PochiWorldArtwork.swift`: 本棚・机・ボール・床の本・紙・小さなゴミのオリジナル16×12ピクセル絵。整数4倍・nearest表示で犬と同じドット密度。外部素材/ライブラリ/APIなし。
- 読書達成で本棚が整い、本が床から消える。掃除達成で対応する小さなゴミが片付き犬が喜ぶ。勉強達成で机と紙が整う。運動のボールは休んだ期間は隅で控えめに表示。
- 新しいclean反応を追加し、全テーマの即時反応を既存の最大3組の反応キューに統合。履歴側からの削除でも、取り消した記録に対応する反応をキャンセルする。
- 累計3回から本棚/机のそばで眺める仕草やくつろぎ、運動7回からボール遊び、全体14回から近づく/くつろぐ頻度、30回から長めにくつろいで眠る特別な動作の組み合わせを追加。しきい値はPochiGrowthPolicyに集約。既存の累計日数による仕草/思い出も維持。
- ボール遊び中は隅のボールを隠し、二重に見せない。中断/完了時に一時アイテムを片付ける。
- 朝6〜10時、昼10〜19時、夜19〜23時、深夜23〜6時のローカル時間で行動を切り替える。深夜は呼吸を伴う睡眠ループとし、思い出の新規再生や激しい自律行動を翌朝まで保留。タップには短く静かに反応する。
- 深夜の達成記録は受け付け、反応後は睡眠へ戻る。昼間の睡眠記録は短い昼寝へ連動。睡眠の合間に何度も立ち上がらないように整理。
- 日付/時刻/時差の変更と復帰で状態を更新。時間帯の変更でジャンプを中断した場合も、犬を床の高さに戻す。
- 新しい導入文と頻度の説明を5言語に追加。数値ゲージ・病気・悲しみ・成長リセット・責める通知は追加しない。

### 検証

- `Tests/WorldRegression/main.swift` を追加し、本体と同じFoundationソースで状態テストを実施。ログ: `.build/habit-world-regression.log`。
- 成功: 日/週の期限、曜日による予定、今日の途中期間、未達3日→達成→取り消し、読書/掃除の同時存在、固定表示枠、削除/編集、初回導入、10年の未起動、重複/未来のログ、メタデータ保存往復、ローカル多言語分類、時差移動、朝昼夜深夜、夏時間開始/終了、時計巻き戻し、週が変わる0時。
- 既存 `Tests/ModelRegression/main.swift` も成功。旧JSON、目標境界、20件の多言語保存、空配列、削除済み習慣の履歴、反応キュー/取消/集約、月カレンダー/うるう年/夏時間を再確認。
- 初回/レビュー後のSimulator SDKビルド成功: `.build/habit-world-build.log`、`.build/habit-world-reviewed-build.log`、`.build/habit-world-final-build.log`。最終の睡眠調整版は下記へ追記。
- 5言語のstrings構文、git差分チェック成功。
- `scripts/render_world_preview.swift` で実際のモデルと素材から `Design/WorldPreview/habit-world.png` を生成して目視確認。未達→読書→読書と掃除→深夜の構図を比較。これは素材の組み合わせであり、SpriteKit/SwiftUIを実行したスクリーンショットではない。

### 未実装・実行時の未検証

- 既存の週目標を維持。曜日の予定は状態モデルとテストで扱えるが、曜日指定UIや個別の締切時刻は未追加。
- お腹を見せるための新規スプライトは未追加。30回の特別な仕草は既存の統一フレームを組み合わせる方式。
- シミュレーター/実機での配置・操作・再起動・夜中の実際の動作・タイムゾーン通知の配信は未確認。起動を何度も試してはいない。
- 次回は小さいiPhoneで、登録テーマだけの家具、3個の床小物、記録/取消での片付け、夜中の再開と達成、朝への切り替え、ボール遊びの中断、アルバム撮影を確認し、動作の間と配置を調整する。
- 睡眠の最終調整まで含めたビルドも成功（exit 0、generic iOS Simulator SDK、署名なし）: `.build/habit-world-sleep-final-build.log`。ログに警告/エラーなし。

## 動作で目・尻尾の位置が崩れる問題の修正（2026-10-22）

### 原因と修正

- 柴犬: 横向きの目座標を正面のまばたきにも使い、目の消し残し/別位置への描画が発生していた。頭/尻尾を平坦な絵から矩形で切り出す処理が胴体まで消し、座る/首かしげ/尻尾の付け根を崩していた。
- ポメラニアン: 歩行・座る・あくび・まばたき・うとうとの計7フレームで、尻尾32画素が胴体から実際に孤立していた。修正前の計測は `.build/sprite-components-before.txt`。
- `PochiSpriteGeometry.swift` に顔の原点、目、頭全体の傾き、胴体/尻尾の付け根、首輪の座標を集約。顔は目・鼻・耳・口をローカルな一枚の頭レイヤーへ描き、最後に全体を同じ座標変換で配置。
- ダルメシアン/ポメラニアンは正面/横向きで目の間隔を統一。閉じた目も同じ位置に描き、耳と顔の別々の傾き計算を廃止。
- 尻尾は胴体の姿勢から根元を決めて描き、振る動きは先端を曲げる方式へ変更。座る・睡眠・呼吸も付け根が胴体から離れない。
- 柴犬は元のシルエットと寝姿を利用して、顔/胴体/尻尾のレイヤーに分離。横顔の目を正しく消してから表情を描き直し、こちらを見る顔の目も専用の同じ座標へ統一。切り出した矩形で体の一部を消す動きを廃止。
- 柴犬の輪郭の半透明ノイズと焼き込み済みの赤い首輪を取り除き、選択中の首輪のみを同じ顔座標で重ねる。色は近いフラットな色へ統一。
- 座る柴犬の背中/尻尾の接続、眠るポメラニアンの胴体が丸く下へ飛び出して尻尾に見える部分も、一覧を見て再調整。寝起きは整った低い立ち姿へ変更し、横たわった頭だけを切り出して上へずらす処理を除去。
- 耳の動きは先端のみを小さく曲げ、目/耳の根元が動かないように維持。首輪・チャームも姿勢別の共通アンカーへ追従。
- 32フレームの番号、SpriteKitの行動キュー/反応/生活リズム、犬種設定、保存形式は維持。

### 検証と成果物

- `Tests/SpriteRegression/main.swift`: 3犬種×32=96フレームを実際の描画結果で検証し成功。独立した尻尾/足/画素がないこと、目とまばたきの位置、余分な目の消し残し、目の間隔、鼻の追従、付け根の固定、全画素の不透明/透明、アトラスサイズを確認。ログ `.build/sprite-regression.log`。
- `scripts/render_motion_review.swift`: 各犬種の全32フレーム一覧を生成して目視確認し、修正を反映して再生成。首輪付き一覧とGIF: `Design/MotionReview/{shiba,dalmatian,pomeranian}-frames.png`、同 `*-motion.gif`。元の透明アトラスも同フォルダに保存。
- 修正前の一覧は `Design/MotionReview/Before/` に保存。GIFはフレームのサンプルで、SpriteKitの移動や実アプリの録画ではない。
- 初回ビルド成功 `.build/sprite-rig-build.log`。最後の耳と睡眠姿勢まで含む最終ビルド成功（exit 0、generic iOS Simulator SDK、署名なし）: `.build/sprite-rig-final-build.log`。
- シミュレーター/実機での最終再生、タップや習慣反応中の切替、首輪/チャーム全種類の実画面は未確認。次回はプロフィールで各犬種のご飯・睡眠と、正面/首かしげ/尻尾の動きを確認する。

## 2026-10-22 首輪の撤去と犬種別3色

### 変更

- 首輪/チャームのSpriteKit描画と姿勢別アンカー、プロフィール/オンボーディングの選択UIを撤去。旧保存キーは消去しない。旧プロフィール画像/共有用プレビューとウィジェットも首輪なしの同じドット絵へ統一。
- `PochiCoat.swift` に9パレットを定義。柴犬: 赤柴/白柴/黒柴、ダルメシアン: 黒ぶち/茶ぶち/レモン、ポメラニアン: オレンジ/クリーム/ブラック。
- 全体への色かぶせを廃止。アトラス内の毛色・斑点色のみを置換し、目/輪郭/舌/クリーム模様/透明度は保持。全32フレームへ同じパレットを適用。
- 柴犬の既存`pochiCoat`（kinako/milk）はそのまま利用。追加犬種は`pochiCoat.dalmatian`/`pochiCoat.pomeranian`に別々に記憶。未購入犬種の見本表示と購入による犬種選択の区別を維持し、課金仕様は変更しない。
- 共通の毛色ボタンは名前と選択チェックを表示。狭い幅/長い翻訳では縦並びに切り替え。プロフィールの犬種切替と毛色選択をプレビューへ即反映。
- ウィジェット用に同じレンダラーから9種類の32px画像を生成。犬種/毛色変更時に更新し、既存のプレミアム判定を共有設定へ同期。
- 日本語/英語/韓国語/簡体字/繁体字の毛色名と設定の説明を追加。設定の「首輪、チャーム」という案内も修正。

### 確認

- `Tests/CoatRegression`: 成功。9色×32=288フレームの同一形状、目や輪郭の維持、3色の差、旧設定、犬種別の永続化/再読込、未知値への対応、旧アクセサリ設定の保持を検証。ログ `.build/coat-regression.log`。
- `Tests/SpriteRegression`: 96フレームの顔・尻尾・画素の接続チェックに成功。`.build/sprite-regression.log`。
- 見本 `Design/CoatReview/nine-coats.png` を開いて実際に確認。9種類の全アトラスも同フォルダに保存。`Design/MotionReview/` の3犬種全32フレーム一覧/GIFも首輪なしで再生成。
- 初回ビルド/最終ビルドとも成功（署名なし、generic iOS Simulator SDK、exit 0）。`.build/coat-build.log` / `.build/coat-final-build.log`。
- 実アプリ/シミュレーターの画面操作と、ウィジェットの実表示は未確認。素材の目視確認とビルド確認を実画面確認と混同しない。

### 次回の実画面確認

1. プロフィールで各犬種/各色を選択して食事・睡眠をプレビュー。
2. 別の犬種に切替→戻す/アプリ再起動で色が残ることを確認。
3. 新規オンボーディングの柴犬3色、購入済み/未購入の犬種選択、各言語のボタン幅を確認。
4. ウィジェットに選択犬種と毛色が反映され、首輪が表示されないことを確認。
- 追加の最終検証: `Tests/ModelRegression`（旧保存形式/習慣/履歴/反応キュー/カレンダー）と`Tests/WorldRegression`（約束の期限/取り消し/削除/日時/世界の再計算）はともに成功。ログ `.build/coat-model-regression.log` / `.build/coat-world-regression.log`。5言語のLocalizable.stringsの構文検証と`git diff --check`も成功。

## 2026-10-22 ポメラニアンの毛量・ダルメシアンの犬種らしさ

- ブラウザーでポメラニアンのシルエットとダルメシアンの子犬イラストを実際に表示して確認。AKCの犬種説明も参照。参照先と設計を `Design/CoatReview/BREED_REFERENCES.md` に記録。外部素材のアプリへの導入はなし。
- ポメラニアンの頭を21px幅の頬〜胸の大きな毛のふくらみに変更。胸元と胴体、巻き尾にも毛量を追加し、短い脚が毛の下から見える形へ。耳は毛の間の小さな三角形に維持。
- ダルメシアンの額/頬/口元を丸くし、黒い耳は先細りの長い垂れ耳へ変更。体を少し長くして背中の斑点が見えるようにし、四角い斑点を大小の丸い模様へ変更。尻尾の付け根と後脚も胴体の長さに合わせて調整。
- 頭部は全アニメーションで共通。毛量と姿勢に合わせて顔の原点を調整し、まばたき/目の間隔/鼻/耳を同じ座標変換へ追従。3色すべてとウィジェット用素材を再生成。
- 9色の見本と各犬種の32ポーズ一覧を実際に開いて評価。初回見本から耳の先細り/長さ、ダルメシアンの体と尻尾を再調整。変更前の見本は `Design/CoatReview/BeforeBreedRefinement/nine-coats.png`。
- `Tests/SpriteRegression`: 全96フレームの目/鼻/尻尾の付け根と画素接続の検証に成功。目の検証範囲は新しい耳の位置を除く顔の内側へ変更し、実際の目の期待画素との一致は維持。`.build/breed-refinement-sprites.log`。
- `Tests/CoatRegression`: 9色×32=288フレームの毛色差/目や輪郭の保持/旧設定と犬種別保存の検証に成功。`.build/breed-refinement-coats.log`。
- 初回ビルド成功（署名なし/generic iOS Simulator SDK/exit 0）: `.build/breed-refinement-build.log`。最後の耳の長さ調整後のビルド結果は下記へ追記。
- 実機/シミュレーターでの表示・操作は未確認。次回はプロフィールの3色と、ご飯/睡眠/首かしげ/歩行のゲーム内再生を確認する。
- 最終ビルド成功（exit 0、エラー/警告なし）: `.build/breed-refinement-final-build.log`。`git diff --check`も成功。最終状態のダルメシアン32ポーズ一覧を再度開いて、伸ばした耳と顔の重なりを確認。

## 2026-10-22 犬種間の向きを統一

- 3犬種とも、歩行/待機/座る/食事/睡眠/伸び/耳や尻尾の動きは横顔に統一。こちらを見る/正面まばたき/左右の首かしげ（12,13,14,29）だけ正面にする。
- ダルメシアンとポメラニアンに専用の横顔シルエットを追加。単に片目を消す処理ではなく、左に突き出した鼻先、横から見た口元、顔の後方の垂れ耳や小さな耳を描画。正面は直前に改善した両目と耳/頬のデザインを維持。
- ポメラニアンの胸の大きな毛のふくらみ/巻き尾、ダルメシアンの長い耳/斑点、3犬種×3色、32×32・全32フレーム・nearest表示を維持。保存キー/習慣処理/購入仕様の変更はなし。
- `Design/CoatReview/nine-coats.png` と2犬種の全32ポーズ一覧を開いて実際に確認。`Design/MotionReview/*-motion.gif` と9色のウィジェット素材も更新。変更前の見本は `Design/CoatReview/BeforeOrientation/nine-coats.png`。
- `Tests/SpriteRegression` に向き別の目の数と鼻先アンカーの検証を反映し、96フレームで成功。`.build/orientation-sprites.log`。
- 素材の目視確認は実アプリでの再生確認ではない。実機/シミュレーター操作は未確認。次回の実行環境で、歩行→こちらを見る→横向きへ戻る遷移と、各犬種の食事/睡眠を確認する。
- 最終ビルド成功（exit 0、署名なし/generic iOS Simulator SDK、エラー/警告なし）: `.build/orientation-build.log`。9色×32=288フレームの色/輪郭/設定互換性検証も成功: `.build/orientation-coats.log`。`git diff --check`成功。

## 2026-10-22 ポメ・ダルの横顔を可愛く再描画

- 可愛い子犬イラストをブラウザーで確認し、独自の32×32描画を修正。参照URLは `Design/CoatReview/BREED_REFERENCES.md`。外部画像のアプリ導入なし。
- ポメ: 丸い毛の輪郭、暖かい茶色の縁、短い脚と小さな足、ふわっとした胸と巻き尾。ダル: 丸い頭と頬、短い鼻先、白黒の垂れ耳、ふっくらした胴と短い足。両犬種に瞳のハイライト、頬の色、小さな笑顔。
- 全アニメーションの共通頭部に反映。3色のパレットとウィジェット素材を更新。柴犬・保存キー・履歴・購入仕様は変更なし。
- 見本 `Design/ProfileReview/cute-profiles.png`、9色一覧、両犬種の32ポーズ一覧を実際に画像表示して確認。輪郭と顔の比率を再調整。シミュレーターや実機の画面確認ではない。
- SpriteRegression 成功: 全96フレームの目/まばたき/鼻の位置、尻尾と脚の接続、画素とアトラス寸法。ログ `.build/puppy-sprites.log`。
- CoatRegression 成功: 9色×32フレームのパレット、輪郭形状と顔、旧設定、犬種別保存。ログ `.build/puppy-coats.log`。
- 未確認: 実機・シミュレーターでのゲーム内再生。次回は歩行/食事/睡眠/正面切り替えを確認する。
- 最終ビルド成功（exit 0、generic iOS Simulator SDK、署名なし）。ログ `.build/puppy-final-build.log` にエラー/警告なし。`git diff --check` 成功。

## 2026-10-22 Compact banner ads

- Replaced the records MREC (300x250) with a 320x50 banner in home/records bottom safe-area insets. No banner in settings/onboarding.
- Collapse the slot until load succeeds and on load failure. A dedicated view controller owns presentation; request once on appearance.
- Wait for entitlement lookup and existing ATT flow. Lifetime and legacy subscribers remain ad-free; purchase changes remove the banner.
- Debug uses Google's test banner ID; Release reuses the existing production unit. Reference: https://developers.google.com/admob/ios/banner
- Build passed, generic iOS Simulator SDK, unsigned, exit 0, no warnings/errors: `.build/banner-build.log`. `git diff --check` passed.
- Not verified: simulator/device display, ad delivery and failure layout. Before release, verify the existing AdMob unit supports 320x50 serving and regional consent configuration. UMP consent integration and dashboard configuration were not changed.

## 2026-10-22 Daily representative moments and record-based sharing

- Added PochiDayMoment below the selected day's achievement list in Records, with a representative photo and the existing daily share composer. Achievements remain optional in shared images (off by default).
- Representative selection is shared with the album: manually chosen photo, then latest special story, then automatic daily snapshot. Opening the home scene requests a daily photo even on days with no habit records. Foreground/date refresh requests today's capture; no historical photos are fabricated.
- Home camera now opens a preview with a save-to-today action. Removed sharing from that preview. The captured date is passed through to persistence so a preview left open past midnight cannot be silently saved as the next day's photo.
- Added optional isUserPhoto metadata, preserving old archive decoding. Automatic captures never replace a chosen photo. Manual replacement writes a unique image file before updating the archive, retaining the previous file and metadata if the update fails.
- Fixed photo-only days missing from album enumeration. Date selection and old habit/profile/purchase storage remain intact.
- Added Japanese, English, Korean, Simplified and Traditional Chinese strings; all five strings files pass plutil validation.
- Build passed (exit 0, generic iOS Simulator SDK, no warnings/errors): `.build/daily-moment-build.log`.
- Persistence regression passed: `python3 Tests/MemoryRegression/run.py`; log `.build/daily-memory-tests.log`. Covers deduplication, story/manual priority, automatic overwrite protection, reload, original-file retention, day boundary, legacy decoding, failed archive writes and corrupt archive protection. Actual store code is compiled with only the UIKit image boundary stubbed; real user data is never opened.
- `git diff --check` passed. No visual simulator/device validation performed. Next runtime check: capture/save on home, select today's photo in Records, share with/without achievements, reopen the app, select older dates, and verify photo-only days in the album. UIKit capture/PNG encoding and actual share-sheet presentation remain unverified.

## 2026-10-22 Slower animations and coherent daily behavior

- Replaced the weighted random idle-action bag with PochiDailyRoutine, a session-only Foundation planner. Morning: stretch/look/stroll/sit/rest. Day: explore/sit/rest/nap. Evening: sit/yawn/rest/bedtime. Deep-night sleep and habit-record reactions retain priority.
- Removed ordinary random hopping, repeated welcomes and short arbitrary naps from selection. Learned bookshelf/desk/ball activities replace exploration steps at most once per four minutes after a two-minute settling period, and respect registered themes. Special long rest remains linked to cumulative progress.
- Animation durations are about 1.5x the previous baseline (breed factors 1.45-1.55). Footsteps use slower, consistent cycles; idle strolls alternate between nearby destinations instead of choosing random coordinates.
- Sitting holds for about 14 seconds, lying down about 22 seconds, naps roughly a minute, bedtime roughly 90 seconds; sleep recording keeps the dog resting for two minutes. Reduced repeated jumps in general joy and self-care reactions.
- Activity completion feeds a quiet follow-up into the planner: meals/exercise lead to rest, other activities to sitting. Special stories wait at least 90 seconds after a reaction, are spaced four minutes apart, and favor recent activities; evening excludes energetic exercise stories. Initial stories wait 45 seconds after scene creation.
- Retained SpriteKit action keys, habit reaction queue priority, pause/resume handling, day/night rhythm and existing save formats. No new persisted routine data.
- RoutineRegression passed: coherent episodes, night, phase reset, activity follow-up, learned cooldown and theme gating. Log `.build/routine-regression.log`.
- Runtime pacing, game appearance and actual animation transitions have not been visually verified on simulator/device. Next check: observe morning/day/evening for several minutes, interrupt rest with a recorded habit, then confirm the quiet follow-up and deep-night sleep.
- Final build passed (exit 0, unsigned generic iOS Simulator SDK, no warnings/errors): `.build/calm-routine-build.log`. MemoryRegression passed, including preferred-activity and evening-safe story filtering: `.build/calm-memory-regression.log`. `git diff --check` passed.

## 2026-10-22 Promise-specific recorded reactions

- Added PochiPromiseReaction: stable template mapping for 29 IDs, specific multilingual custom-title rules, icon/category fallbacks, and a calm generic response for unknown content. Plant watering is not drinking; rest is not sleep; stretching is not running.
- Added reactions using existing sprite frames: stretch in place, a slow stroll, awake lying rest, quietly sitting/blinking for breathing, book-side reading, pixel bubbles for bathing, listening with a head tilt, and facing forward for a photo. Study watches quietly without a book; general/social success looks toward the user and wags instead of jumping.
- Detailed reactions normalize to existing long-term learning families. Existing history/profile formats are unchanged. Post-reaction routine and special-story preference use those families.
- Changed pending reaction coalescing to combine only matching actions; distinct sleep/meal/etc. retain their meaning. Queue length is bounded by the finite activity set, with duplicate suppression and per-record cancellation preserved.
- Today's records added from Records queue the matching action for home; past-day additions do not act out now. Cancelling the last active sleep record clears its temporary nap state, while local night-time sleep remains driven by the life phase.
- ReactionRegression passed: 29 template IDs, 22 custom/multilingual/icon cases, learning families and calm follow-up. `.build/reaction-regression.log`.
- ModelRegression passed: legacy data/Unicode/history/calendar, queue order/deduplication, matching-kind coalescing, finite bound and cancellation. `.build/reaction-model-regression.log`.
- Simulator/device playback is not visually verified. Next runtime checks: each reaction (especially bubbles/read/stretch/rest), multi-record queue, cancellation during sleep, and records-tab enqueue followed by home resume. No new external art or network service used.
- Final build passed (unsigned generic iOS Simulator SDK, exit 0, no warnings/errors): `.build/promise-reactions-build.log`. `git diff --check` passed.

## 2026-10-22 Sleeping Shiba app icon

- Replaced the app icon with the exact curled-up sleeping Shiba frame (pose 6) from the game's canonical sprite generator. No redrawing or external image used.
- Trimmed transparent sprite margins, centered the 25x15 occupied pixels on a 32x32 cream canvas, and enlarged with nearest-neighbor interpolation. Output: opaque RGB 1024x1024 PNG at `promise_timer/Assets.xcassets/AppIcon.appiconset/pochi-pixel-icon.png`.
- Generator: `scripts/render_sleeping_app_icon.swift`. Preview images at `Design/IconPreview/sleeping-app-icon-256.png` and `sleeping-app-icon-60.png`; both opened and visually inspected. Previous icon retained at `Design/IconPreview/before-sleeping-icon.png`.
- Verified dimensions and no alpha using image metadata. Device home-screen appearance has not been checked.
- Build passed (unsigned generic iOS Simulator SDK, exit 0): `.build/sleeping-icon-build.log`. `git diff --check` passed.

## 2026-10-22 Tilt face repair (14 / 29)

- Confirmed the Shiba's tilted eyes were deformed in the rendered frame comparison. Per-column shear moved the two columns of a 2x2 eye differently; the old anchor tests accepted the same distortion.
- The shared face transform now keeps each eye's two columns together and caps the head lean at one pixel per side. All pixels in each column retain the same offset to avoid overwriting the eye. Applies to both tilt directions and all breeds.
- Added a regression invariant that the 2x2 eye footprint stays square regardless of its transformed anchor. All 96 frames pass eye/blink/nose/tail/connected-component/alpha checks: `.build/tilt-sprites.log`.
- Opened the native three-breed comparison before and after: `Design/FaceReview/before-tilt-fix.png` and `Design/FaceReview/face-review.png`. Generator: `scripts/render_face_review.swift`. These are sprite renders, not simulator screenshots.
- Regenerated full motion review sheets/GIFs and nine coat atlases/widget assets. CoatRegression passed for all 288 frames and saved settings: `.build/tilt-coats.log`.
- Final build passed (unsigned generic iOS Simulator SDK, exit 0, no warnings/errors): `.build/tilt-fix-build.log`. `git diff --check` passed. In-game playback on device/simulator remains unverified.

## 2026-10-22 Clear home recording entry

- Removed the unexplained four-promise preview and the home-pin selection controls. Home now shows today's completion count, the registered promise count, an Add action, and one clear Record a promise button. The old home-pin preference is left untouched in storage; no promises or history were removed.
- Record opens a medium/large resizable sheet listing every registered promise with its pixel icon and completion check. Selecting an unfinished promise records it, closes the sheet and uses the existing dog reaction. The list scrolls for larger collections.
- Add and Edit are available from the sheet; those actions wait until dismissal before opening the existing editor. Empty state opens creation directly; all-done state changes the home button to View today's promises.
- Home no longer grows a third button row or hides new promises behind a four-item setting. Dog room retains flexible available space. Existing photo/profile controls and banner safe-area placement are preserved.
- Added/updated Japanese, English, Korean, Simplified/Traditional Chinese copy. All five strings files pass plutil; git diff --check passed.
- No simulator/device visual or interaction confirmation performed. Next checks: zero/one/many promises, all completed, long names, sheet scroll/drag, record then dog reaction, and Add/Edit dismissal handoff on small and large phones.
- Final build passed (unsigned generic iOS Simulator SDK, exit 0, no warnings/errors): `.build/home-record-entry-build.log`. No new logic tests added for this UI-only change.

## 2026-10-22 Pochi companion widget replaces legacy widgets
- Removed the old configurable habit dashboard and unused sample Live Activity (Hello/emoji/Dynamic Island placeholder). Kept the extension and widget kind identifier so existing placements can receive the replacement; no shared habit/profile defaults are erased.
- New small/medium dog-first widget uses 54 exported canonical game frames, all 3 breeds × 3 coats, nearest-neighbor integer scaling, bundled existing PixelMplus font and license, and JA/EN/KO/zh-Hans/zh-Hant strings.
- Interactive `PetPochiIntent` cycles look/tail-up/tilt without opening the app or recording a habit. A 0.5-second crossfade accompanies snapshot changes where WidgetKit permits; Reduce Motion/Always-On suppress it. This is NOT continuous SpriteKit or looping frame animation. Official Apple WidgetKit documentation limits update animations to 2 seconds.
- Quiet poses follow local time; 23:00–06:00 sleeping, evening lying down. Half-hour timeline entries, OS-managed delivery. A tap pose is valid for 15 minutes in snapshot calculation and clears on the next delivered timeline entry; exact refresh timing is not guaranteed by iOS.
- Existing purchased breed entitlement and per-breed coat selection reused; invalid values safely fall back. Widget-only reaction keys do not modify main app logs or dog progression.
- `python3 Tests/WidgetRegression/run.py`: PASS (day/night, all nine coat combinations, entitlement/invalid-value fallback, reaction expiry/future clocks, 54 assets).
- App + extension build: `.build/pochi-widget-build.log` (final result noted below).
- Not visually verified in simulator/device. SwiftUI previews provided, not rendered. Device follow-up: verify existing AppIntentConfiguration placement migrates to StaticConfiguration with retained kind, tap intent transitions, localized text and font, large accessibility text, tinted widgets. If an old placement cannot migrate, remove/re-add from the home screen; the app cannot remove a user's placed widget itself.
- Final app + widget extension build succeeded (exit 0), no warnings/errors in build log; `git diff --check` passed.

## 2026-10-22 Store copy and real simulator screenshots
- Prepared five localized listing sets and 15 minimal captioned iPhone screenshots in `Design/AppStore/2026-10-22`; refreshed `STORE_LISTING_COPY.md` to remove obsolete feature/monetization copy.
- Real iPhone 16 Pro Max iOS 18.5 simulator captures, reviewed in all five languages. Onboarding/record food reaction/photo save/album exercised through Device Hub UI. No iPhone 18 Pro or user data touched.
- Fixed the initial blank photo sheet using a single identifiable captured-photo state and verified the actual sheet and save flow. Added DEBUG-only test-ad suppression for capture sessions. Local build passed without logged warnings/errors.
- App Store Connect not changed yet: released 1.03 fields disabled; new version draft creation was rejected by automatic approval as lacking explicit authorization. User asked for permission to create a 1.04 draft (no upload/submission/release). Awaiting answer. Resume details in `Design/AppStore/2026-10-22/STATUS.md`.

## 2026-10-22 Authorized App Store draft and six screenshots
- User authorized new version: created App Store Connect iOS 1.04 draft, status 提出準備中. Names, subtitles, descriptions and promotional text saved for ja/en-US/ko/zh-Hans/zh-Hant. Five saved names/subtitles reopened and verified. No binary upload, review submission or release.
- Expanded actual simulator screenshot sets to six per locale (30 total), with minimalist captions. Added profile, templates and history; recaptured expanded profile sheet to show name/coat. All final contact sheets viewed.
- Remote screenshot upload remains incomplete: native Safari file picker keeps Upload disabled despite valid PNG selection. Multiple UI selection methods and /tmp copy failed; existing screenshot attachments preserved. Evidence and exact resume instructions: Design/AppStore/2026-10-22/STATUS.md.

## App Store Connect purchase configuration update
- Created NON_CONSUMABLE `promise_timer.premium.lifetime`, Apple product ID `6825802653`, reference Pochi Premium Lifetime. Do not create a duplicate.
- Saved initial price: Japan JPY 3,900 with Apple equivalents (US USD 24.99). Product remains 提出準備中, not submitted.
- Saved Japanese name and description. Other four product localizations still pending.
- User explicitly approved all 175 territories after automatic approval review rejected initial availability confirmation. Approval now exists; do not ask again. Availability has NOT been saved.
- Latest user pricing override: Japan stays JPY 3,900; overseas should be JPY 5,900 equivalent in local price points. Overseas update NOT yet saved.
- Native Safari scroll failed with `noWindowsAvailable`, subsequent keyboard interactions did not change AX state. Screenshot and AX modal states diverged. Root cause unconfirmed; do not claim a verified OS lock.
- Screenshot upload remains incomplete. Subscription availability has NOT yet been inspected or changed.
- App code already offers only lifetime for new purchases, preserves verified legacy active entitlements and restore. No app code changed this session.
- Resume at existing IAP product URL /apps/6760613210/distribution/iaps/6825802653: finish worldwide availability, overseas pricing override, remaining localizations, review screenshot; then inspect legacy subscriptions and retry six screenshots for each of five locales. Do not upload a build or submit review.


## 2026-10-22 — Unlocked Safari retry: final verification
- App Store Connect iOS 1.04 draft: ja, en-US, ko, zh-Hans, zh-Hant each contain exactly six screenshots (01–06), 30 total. All six thumbnails in each locale were visually checked after Apple processing; zh-Hant recovered after reload.
- Evidence: Design/AppStore/2026-10-22/asc-{locale}-six-uploaded.png.
- Lifetime product 6825802653: all 175 territories saved; Japan JPY 3,900; 174 overseas territories use Apple equivalents of JPY 5,900 (USA USD 39.99). Overseas prices are manually managed. Five product localizations saved.
- Legacy monthly/yearly remain available: action-time consent pending for Apple's end-of-current-billing-cycle service/refund agreement. Do not accept or stop until user replies to pending question.
- Product review screenshot still missing; no review submission, release, or binary upload performed.
- No application code changes or build/tests in this store-configuration session.


## 2026-10-22 — Legacy subscriptions stopped
- User explicitly approved stopping both after the Apple service/refund conditions were explained.
- Monthly promise_timer.monthly (6760938401) and yearly promise_timer.yearly (6760938390): confirmed Developer Removed from Sale and 0 of 175 territories selected. New purchases and renewals stopped according to Apple's confirmation.
- Evidence: Design/AppStore/2026-10-22/subscription-monthly-stopped.png and subscription-yearly-stopped.png.
- Existing billing-period entitlements remain supported; product records were not deleted. No binary upload or review submission.

## 2026-10-22 — Shiba front face refinement
- Replaced the narrow pointed frontal head with a symmetric 16px-wide face, rounded cream cheeks, short ears, small centered nose and eye highlights.
- Shared face map applies to look/blink/left and right tilt (12, 13, 14, 29). Updated frontal eye anchors and tilt pivot together; profile and resting poses unchanged.
- Regenerated canonical widget sprites so front-facing widget frames match the app.
- Visually inspected actual renderer output for all three coats and four front poses: Design/FaceReview/shiba-front-three-coats.png. Comparison with other breeds: shiba-face-rounded.png; original: before-shiba-face.png.
- Rendering utilities compiled and ran successfully. No app-wide build, simulator run or unit tests performed for this artwork change.

## 2026-10-22 — Reserve banner space before loading
- Banner slot now reserves its 320×50 creative area, label height, spacing and padding before consent/SDK eligibility and throughout loading/failure.
- Eligibility only controls creating the ad controller; it no longer inserts/removes the entire bottom inset. Unloaded label/creative remain invisible and inaccessible.
- Premium, onboarding and store-capture exclusions remain. No build/tests or simulator verification performed for this change.

## 2026-10-22 — Simplify promise creation
- Removed the category picker (care/home/learning/connection/hobbies) from promise add/edit and onboarding custom creation. Removed the unused editor category binding.
- Stored categories remain intact; templates retain their categories and existing local title/icon reaction inference is unchanged. No persistence migration.
- Swift frontend syntax parsing passed. No full build or simulator visual confirmation.


## 2026-10-23 — App Review submission in progress
- User authorized submission and keyword updates. All five locale keywords and release notes saved; review notes updated for the new lifetime product. Copy: Design/AppStore/2026-10-22/submission-listing-updates.json.
- Release archive 1.04 (64) created successfully with signing. Existing cached SwiftPM artifact path corrected to local .build/SourcePackages.
- xcodebuild export/upload succeeded. GoogleMobileAds and UserMessagingPlatform vendor dSYMs were missing (non-blocking upload warnings). Build 64 processed and attached to 1.04 draft.
- Export compliance answer pending explicit user consent after automatic approval review blocked the attestation (static app-source search alone did not verify SDK encryption). Async confirmation question sent; do not bypass.
- Lifetime IAP review notes saved. Review screenshot being prepared using actual UpgradeView and local StoreKit testing, isolated to DEBUG simulator; Release 64 is unaffected.
- No App Review submission completed yet. Resume with export compliance consent, IAP screenshot upload/add to review, version add to review, then final submit and verify Waiting for Review.


## 2026-10-23 — Submitted successfully at 00:15 JST
- App 1.04 (64) and Pochi Premium Lifetime both visibly WAITING FOR REVIEW in submission 4ae3e758-440a-4bb2-82ae-a2c586e7088e. Proof: submission-complete.png and submission-waiting-for-review.png. Details in Design/AppStore/2026-10-22/submission.json.
- User explicitly approved the export-compliance answer after auto-review rejection. Saved None of the algorithms listed, then added version to the same draft as the lifetime IAP and submitted both.
- All five locales now have localized keywords/release notes. Japanese/English keywords emphasize relevant features and do not use third-party app/brand names. Existing five sets of six screenshots retained. Review notes updated with purchase path and legacy-entitlement policy.
- IAP review screenshot uploaded: premium-review-en-local.png, actual UpgradeView on iPhone 16 Pro Max iOS18.5, Apple local StoreKit test product (JPY3900, English). Price and purchase button rendered and visually inspected. No real purchase was performed. Local test session code/framework dependency removed after capture; simple DEBUG-only direct purchase-screen entry retained. Uploaded Release64 does not contain this debug entry or test config.
- Release archive/upload succeeded, vendor SDK missing dSYM warnings non-blocking. Project build number aligned to 64. Existing auto-release-after-approval setting retained.
- No further action needed for submission. Await Apple review; do not resubmit or upload another build without a reason.


## 2026-10-23 — Dark mode support
- Converted shared colors to 15 light/dark asset colors, replaced fixed white UI surfaces, and separated accent button text. Adjusted light accent contrast and disabled-button legibility.
- SpriteKit room follows current SwiftUI color scheme, including live changes, while preserving time-of-day palettes and dog pixels. Widget uses the shared dynamic color catalog. Legacy shared artwork keeps a light paper palette.
- Added DEBUG-only appearance entry for real screen/component captures with disposable editor/log bindings. No storage format or habit/profile data changes.
- Debug Simulator and Release device builds succeeded. Visually reviewed six major views in both appearances and live switching on iPhone 16 Pro Max iOS18.5. No iPhone18Pro used. Evidence and limitations: Design/DarkModeReview/README.md; contrast.txt records opaque-pair contrast.
- Normal initial onboarding and home/tab bar verification captured separately. Actual widget presentation and broader OS/device matrix are not verified.
- Not part of uploaded/submitted 1.04(64); no App Store Connect submission changes in this task.

## 2026-10-23 — Direct Xcode device purchase testing
- User prefers ordinary Xcode Run on their iPhone. Added StoreKit/PochiPremium.storekit (one non-consumable, same production product ID, JPY3900, five product localizations).
- Shared promise_timer scheme LaunchAction (Debug) references ../../StoreKit/PochiPremium.storekit. Added a project navigator file reference only, outside target-synchronized sources; no resource copy or Archive testing reference.
- Project plist, scheme XML/path and product fixture validated. Generic iOS Debug build succeeded: .build/local-purchase-device-build.log. No StoreKit fixture copy appears in the build log.
- No purchase/restore/real-device Xcode launch verified in this turn; user can press ordinary Xcode Run, then Settings > Premium > Buy once. Local reset instructions in StoreKit/README.md. No production payment or App Store Connect change.

## 2026-10-24 — Time spent together
- Added open-ended sessions: Start with Pochi, select a habit, pause/resume, Done, or confirmed discard. Existing one-tap completion remains available.
- Persisted timestamp-based sessions survive backgrounding/relaunch; preset snapshots survive edits/deletion. Optional duration and session IDs preserve old HabitLog JSON. Repeated sessions merge into the completion day's existing achievement without increasing its count; session IDs make replay idempotent.
- Added ongoing reading, tidying, listening and breathing episodes plus activity-specific combinations of existing moves; completing/pause/discard exits companionship correctly. Reduced Motion uses quiet seated episodes.
- Added 5-language strings and updated onboarding explanation. DayLogListCard shows recorded duration.
- Verified running and paused relaunch, completion, repeat-session merge, discard, and existing one-tap logging on iPhone 16 Pro Max / iOS 18.5. Saved 2 reading sessions as one 85.02-second achievement plus a separate untimed record. Details/screenshots: Design/TogetherReview/README.md.
- Model, Together, Routine and Reaction regressions pass. Simulator build passes. No release submission or production data changes.

## 2026-10-24 — Strength training growth
- Added persistent, additive strength-day progression with 3/7/14/30-day milestones. Same-day exercises count once; rest and deletion retain earned progress. Existing strength histories migrate from their saved title and preset ID.
- Home now starts strength training directly, with elapsed time and a growth counter. Other habits remain reachable. Profile supports automatic growth and unlocked body selections.
- Added pixel-native muscular variants for all breeds/coats and eight extra poses; pushups, squats, curls, flexing and proud walking join the companion animations. Widget uses the same body renderer and shared progress.
- Debug Simulator app/widget build and Model/Reaction/Routine/Together/Strength/Sprite regressions pass. Existing Sprite assertions updated to match the already-shipped-in-source October 22 face refinement.
- Verified completion, same-day deduplication, restart persistence and profile locks on iPhone 16 Pro Max / iOS 18.5; visually inspected generated growth stages and actual mature SpriteKit preview. Details and limits: Design/MuscleReview/README.md.
- No App Store upload or submission. Real-device and actual widget presentation are not verified in this turn.

## 2026-10-24 — Canine strength movements
- Replaced upright human-like flexing and dumbbell arms with quadruped pushups, hind-leg lowering, a mouth-lifted dog toy and proud tail wags. All eight training poses derive from the normal profile dog.
- Replaced large circular muscles and abdominal lines with modest silhouette growth around shoulders, chest and haunches. Preserved paws, facial features, sitting and resting sprites.
- Strength regression now checks proportion bounds, unchanged paws, floor contact and horizontal training silhouettes across all 3 breeds and 5 stages. Strength/Routine/Together checks and Debug app/widget build pass.
- Inspected regenerated growth and exercise sheets plus the actual iOS 18.5 simulator preview. Evidence: Design/MuscleReview/canine-exercises.png. Existing growth data and thresholds are unchanged; no App Store upload.

## 2026-10-24 — Strength onboarding and product copy
- Rebuilt the three-step onboarding around meeting Pochi, selecting exercises, and understanding elapsed timing plus cumulative 3/7/14/30-day growth. Added a clearly labeled day-three preview, trial movement, and rest reassurance.
- Shared strength-only catalog now supplies onboarding and templates. New custom exercises carry a stable strength identity so arbitrary names still contribute to growth. The home start action respects the chosen exercise.
- Updated home/add/edit/weekly-summary/profile/Settings/Premium/widget copy in all five locales. Existing non-training data is retained under previous habits and in history.
- Debug Simulator app/widget build, WorkoutCatalogRegression, ReactionRegression and ten localization-file checks passed. Fresh SE3/iOS18.5 onboarding through selected-pushup timing, completion, one-day growth and reinstall/relaunch persistence verified. Templates and Settings visually checked.
- Screenshots and limits: Design/WorkoutOnboardingReview/README.md. No App Store upload or submission.

## 2026-10-24 — Let Pochi's changes be a quiet discovery
- Per user direction, removed growth promises, milestone explanations, countdowns, and the profile's body-stage chooser. Onboarding now shows the normal dog and explains training only. Updated Settings, exercise forms, Premium and widget copy in all five locales; removed the widget's strength-day badge.
- Automatic body/motion progression, its saved history, and existing stored appearance preferences remain intact. No growth or record data was reset.
- Debug app/widget build passed without diagnostics; all ten localization files passed lint. Reviewed the three onboarding steps on SE3/iOS18.5. Updated final-step evidence: Design/WorkoutOnboardingReview/06-ready-without-growth-ja.png. Earlier growth-preview screenshots are superseded.

## 2026-10-24 — Complete strength-only renewal
- User authorized removal of reading and other habits. Removed their active UI and added an idempotent migration that keeps only strength exercises/history/timers, preserving durations and session identity. Legacy-only users receive a strength starter; intentionally empty lists and new-install onboarding remain supported. Original store strings have an internal recovery copy.
- Removed unused habit landscapes, collections and theme-based sharing UI. Exercise environment and exercise/rest stories replace reading-linked surroundings; reading story memories no longer appear. Saved photos and earned body changes remain.
- Debug app/widget build, WorkoutMigrationRegression, StrengthRegression and MemoryRegression passed. Existing Pro Max/iOS18.5 simulator upgraded from mixed data: only the completed strength entry remains, with its existing 20-second duration intact.
- Evidence/limits: Design/WorkoutRenewalReview/README.md. No App Store upload/submission.

## 2026-10-24 — Calm, uncluttered room
- Kept the normal daytime naps, evening yawns/bedtime, deep-night sleep, sitting, walking and stretching. Removed habit-based shelf/desk/ball/clutter rendering and temporary book/ball episodes; old prop-related motion requests safely fall back to resting.
- Removed progress-based prop activities from the idle routine. The first exercise memory now describes a tail wag; its dog movement and later playful gestures need no objects. Training animations remain available during workouts.
- Routine regression covers every time-of-day phase with advanced legacy progress, no idle props/workout moves, preserved naps and active strength moves. Five localization files and whitespace checks pass.
- Debug app/widget build passed with no diagnostics (`.build/quiet-room-build.log`). Updated Pro Max/iOS18.5 simulator and visually confirmed the uncluttered home; screenshot: Design/WorkoutRenewalReview/quiet-room.png. No App Store upload.

## 2026-10-24 — Sets, core workouts, compact home and gentle prompts
- Added 11 basic exercises with distinct icons, upfront editable reps/time/sets, custom exercises and onboarding defaults. Countdown workouts pause between sets; results can be accepted unchanged or edited per set. Existing history/session formats remain decodable.
- Home uses direct exercise buttons and a smaller room that preserves the full dog. Each basic exercise has a dog motion; core movements tremble and workouts show sweat. Daily photos now require an active workout capture and a saved record; no idle/backfill photos.
- Refined all three breeds' frontal eyes/mouths, regenerated widget frames and replaced the icon with the exact pushup sprite. Removed the introductory Settings text.
- Latest user direction supersedes interstitial ads/AdMob setup: low-frequency Premium offers after successful workout saves, with subscriber/product guards; native rating requests have separate cadence and a shared cooldown. No new AdMob unit was created.
- Debug app/widget build, Together/Prompt/Catalog/Migration/Memory/Sprite/Strength regressions, five locale checks and whitespace validation pass. Pro Max UI confirms countdown/set pauses, partial completion, saved values/photo, persistence and compact layout. Details: Design/WorkoutSetsReview/README.md.

## 2026-10-24 — Match the front face to the profile
- Compared actual side/front renderings. Shiba's front face had a larger head and a different eye/blush/mouth style; Dalmatian/Pomeranian had smaller front eyes than profile eyes, and inconsistent ear/fur details.
- Matched Shiba's frontal head dimensions, plain eyes and muzzle palette to its profile. Shared the same round eye drawing in both directions for Dalmatian/Pomeranian; aligned Dalmatian ear/spot detail and reduced Pomeranian frontal ruff height. Tilt transforms now preserve each breed's whole eye width.
- Regenerated the 54 widget frames and added eye-style consistency coverage to the existing sprite regression. Sprite, Coat and Strength regressions pass. Comparison from actual production rendering: Design/FaceReview/after-consistency.png (left profile, right front).
- Debug iOS Simulator app/widget build passed without diagnostics (`.build/face-consistency-build.log`). No App Store upload.

## 2026-10-24 — Larger Pochi, compact exercise tiles and actual sets
- Enlarged the dog inside a 190-point home room by using a 160-point logical viewport. Exercise tiles are now 68 points tall instead of 126, with only reps/seconds shown. Added square-pixel artwork for all 11 exercises, shared across home, onboarding, editing and records.
- Removed planned set counts from setup/onboarding and the live workout. Each completed set offers another set or recording; results contain completed sets plus only the current partial set. Legacy stored plan counts remain decodable but do not end a workout or prefill unperformed sets. Manual record entry starts with one set.
- Active workouts now continuously repeat the exercise motion, without idle episode breaks. Starting a set cancels any prior completion reaction that could overwrite training frames. Core shaking is visible at the larger scale. Sweat appears in brief outward bursts every 5–8 seconds, disappearing between bursts and during rest; Reduce Motion suppresses it.
- Debug app/widget build passed with no diagnostics. TogetherRegression covers continuing beyond an old set target, actual-only defaults, rest/relaunch, timed caps and the existing 20-set record limit. MemoryRegression, five localization lint checks and whitespace validation pass.
- SE3/iOS18.5: pushup high/low frames differ by 19 screenshot pixels, plank tremble changes horizontal position, countdown auto-rest/relaunch/next set work, and records show 1 pushup set and 2 × 30-second plank sets. Pro Max home shows all 11 tiles; a 16-frame squat sequence confirms isolated sweat bursts separated by clear frames. Evidence: Design/HomeWorkoutReview/README.md. No App Store upload.

## 2026-10-24 — Select an exercise, then start
- Replaced the home exercise grid with one prominent Start Workout action, followed by a compact list of today's completed exercises. Preserved the enlarged dog room.
- The selection sheet now keeps all exercise tiles and a fixed bottom start panel on the same screen. Selection has a border/checkmark and accessibility selected state. Start is disabled until a choice is made; defaults start directly without an intervening settings form.
- Reps/time changes are optional in a secondary sheet. Draft changes survive switching between exercises during selection, and only the chosen plan is persisted on start. Custom addition and name/icon editing remain available from selection. Adjusted the target sheet height so the input is visible on SE3.
- Debug app/widget build passes without diagnostics (`.build/workout-start-flow-build.log`); five locale files and whitespace checks pass. SE3 UI verified selecting, changing plank to 5 seconds, switching away/back without losing the draft, starting with the changed target and automatic rest. Pro Max UI verified direct 10-rep pushup start with no settings step. Both simulators updated to final build; no App Store upload.
- Evidence: Design/WorkoutStartReview/home-se.png and selection-se.png.

## 2026-10-24 — Keep Pochi visible through selection and start
- Replaced the modal exercise picker with an embedded home panel. Pochi stays outside the scrolling list and remains in the same scene when training starts. Portrait stacks the room above selection; landscape puts it alongside selection.
- Only exercise choices scroll. The selected exercise and start action stay fixed. Reps/time adjustments now appear inline with steppers and quick targets, keeping Pochi visible without a keyboard or sheet.
- Debug app/widget build passed without diagnostics (`.build/visible-pochi-start-build.log`). SE3/iOS18.5 UI verified scrolling to the last exercise, inline target changes, preserving selection through rotation, starting the edited 6-second plank, and automatic rest. The disposable workout was discarded without recording.
- Evidence: Design/VisiblePochiReview/selection-se.png, scrolled-se.png and landscape-se.png. No App Store upload.

## 2026-10-24 — One-button finish, rep-only records, personal name and animation recovery
- Removed the post-workout result/rep editing sheet from live training. Finish and save records the current values directly and returns to selection with confirmation text. Timed workouts stop at zero and wait for this button; they do not automatically save. Removed the intermediate Finish Set / Next Set step from the live flow. Manual history entry retains its independent editor.
- Repetition workouts show only the target reps, without elapsed time. New rep sessions do not add duration to history; legacy rep-only durations are hidden. Timed session values, partial seconds, existing history, session IDs and retry deduplication remain intact.
- Home now uses the chosen name in its training title, including long-name scaling. Onboarding still includes the name field; its intro now describes choosing reps or time.
- Active workout actions recover after scene attachment/resumption or a missing action; routine phase changes no longer interrupt training. Pushup/squat rhythms are more visible. Reduce Motion keeps slow deliberate non-core exercise poses rather than replacing the exercise with a static sitting dog, while suppressing core tremble and sweat.
- Debug app/widget build passed with no diagnostics (`.build/direct-workout-record-build.log`); TogetherRegression includes new rep-only duration/aggregation/retry coverage and passes. All five locale files and whitespace validation pass.
- SE3/iOS18.5 UI: Finish and save returns directly to selection; 6-second plank stops and waits for button before saving; renaming to こむぎ updates the home title; rep screen has no elapsed clock. After switching to records and back, screenshots show distinct high/low pushup frames. Evidence: Design/DirectWorkoutReview/. No App Store upload.
- Follow-up UI refinements: moved the single shared banner below the TabView, so it sits underneath the tab buttons across all three tabs. Existing premium/onboarding eligibility and production unit are unchanged. Removed the record page's unused large-navigation-title area with inline title mode.
- Core exercises now use uneven balanced tremor bursts with a brief bracing hold, combining small horizontal and vertical offsets without distorting the sprite or accumulating position drift. Reduce Motion continues to suppress these tremors.
- Profile editing now uses local drafts for name, breed and all three coats. Save commits them and refreshes widgets once; Cancel or sheet dismissal leaves stored settings unchanged. Removed the separate Use This Breed / Selected button. Premium entitlement is checked before saving a locked breed. Preview coat selection now actually uses the draft coat without changing the home dog. Onboarding's original naming field remains unchanged.
- Simulator confirms the actual AdMob test creative appears below all tab buttons. Records now start directly beneath the inline header; rep-only history has no duration label. Screenshot: Design/DirectWorkoutReview/records-banner.png.
- Final profile QA on SE3: changed the draft name, pressed Cancel, and verified the home remained こむぎ; changed it again and pressed Save, then verified the home became まめ. The editor no longer contains the old breed-confirm button. Four side-plank frames show the active core posture and tremor sequence; the disposable session was discarded without recording. Final Debug app/widget build and whitespace checks pass.

## 2026-10-24 — Supine crunch and distinct canine exercise poses
- Added eight pixel frames for belly rest, half/full crunch, alternating dead bugs, raised bridge and alternating bird dogs. Kept each breed's existing profile face and coat palette, bent canine paws and connected silhouettes across all growth stages.
- Crunch cycles from supine rest through a half curl to the raised curl and back. Dead bug alternates extended paws while lying on the back; bridge raises the hips; bird dog alternates reaches from the plank stance. Side plank holds its tilt, and existing intermittent core tremor/sweat behavior remains.
- Debug app/widget build passes (.build/workout-pose-build.log). StrengthRegression passes, including distinct pose comparisons and opaque, connected pixel geometry for all eight frames, three breeds and five growth stages.
- Reviewed generated sprite sheet and verified distinct crunch frames in the SE3/iOS18.5 running app. Discarded the verification session without saving a workout. Evidence: Design/WorkoutPoseReview/. No App Store upload.

## 2026-10-24 — Correct belly-up head orientation; simplify records
- Replaced the quarter-turn head with a vertically rolled profile: ears face the floor while the entire face curls with the torso. Preserves head aspect ratio and keeps eyes/muzzle in the same transform for all three breeds. Updated the generated pose sheet.
- Removed the set-count line from the daily record list; recorded repetitions/seconds remain visible and stored workout data is unchanged.
- StrengthRegression passes for every breed/growth stage, including connected pose geometry. Final Debug app/widget build and whitespace checks pass. Viewed the corrected crunch in the QA simulator and discarded that verification session.

## 2026-10-24 — Whole-body crunch and seconds-only records
- Rebuilt the belly-up torso with a rounded lower back and shoulders that rise with the head. Forepaws tuck toward the chest instead of staying fixed, and removed the stretching rectangular neck.
- Added two intermediate crunch poses (five curl levels total). The return phase is slower than the rise, with brief holds at the top and bottom. Added `crunch-motion.gif` to the native sprite review generator for all three breeds.
- Removed the redundant together-duration line from daily records. Timed workout values remain displayed in seconds; storage is unchanged.
- StrengthRegression passes, including distinct intermediate poses and connected opaque silhouettes across every breed/growth stage.
- Final Debug app/widget build and whitespace checks pass; updated the QA simulator installation.

## 2026-10-24 — Dedicated belly-up character redraw
- Replaced rotated/inverted standing heads with explicit belly-up pixel drawings for each breed, with the muzzle pointed upward and ears below the eye. Preserved coat colors, Dalmatian markings and Pomeranian fur outline.
- Rounded the torso and haunch, tucked forepaws against the chest, and reduced the curl to a small combined head/shoulder movement across five discrete levels. Dead-bug reaches and hip bridge use the same supine character.
- StrengthRegression passes for every breed, coat and growth stage, including distinct intermediate poses and connected silhouettes. Updated the sprite sheet and animated preview.
- Final Debug app/widget build and whitespace checks pass; installed the redraw on the QA simulator. Final preview: Design/WorkoutPoseReview/crunch-redrawn.gif.

## 2026-10-24 — Restore quadruped crunch
- At the user's request, abdominal training now cycles the existing crouch/stretch poses again, without showing any of the supine crunch frames. The dog keeps its established face and quadruped appearance.
- Debug app/widget build and whitespace validation pass.

## 2026-10-24 — Remove remaining supine workout animations
- Restored dead bug to the existing quadruped plank posture with core tremor, and hip bridge to the existing crouch/stretch cycle. Reduce Motion also uses the quadruped plank for dead bug.
- Confirmed the live workout view no longer references any belly-up poses, including abdominal training. Whitespace validation passes.
- Debug app/widget build passes.

## 2026-10-24 — Workout sound cues
- Added four short original synthesized sounds for start, the last three countdown seconds, timer end and successful live-workout save. Removed the previous fixed system timer beep. Audio uses an ambient mixing session to respect the silent switch and avoid interrupting/ducking music, and releases the audio session after playback.
- Added a persistent default-on Workout Sounds toggle under Settings > Sound, translated in all five locales. Turning it off stops current playback immediately. Background/inactive playback is suppressed.
- Countdown tracking emits at most one beat per remaining second, suppresses duplicate timer ticks and pause/resume repeats, and plays no missed countdown sequence on return. Timer end still waits for the manual Finish and Save action.
- WorkoutSoundRegression passes: countdown/short timers/pause/background/deduplication plus four distinct valid WAV signals with silent endpoints and unclipped peaks. Debug app/widget build passes without diagnostics, all locale files validate, and whitespace checks pass.
- SE3 UI verified default-on switch, switching off, persistence after app restart, and switching back on.
- SE3 UI verified a 6-second timer reaches the manual-save waiting state; discarded the verification session without adding records. No App Store upload.

## 2026-10-24 — Visible core effort and intermittent sweat
- Gave live workouts a dedicated SpriteKit action key so existing idle/celebration actions cannot satisfy the recovery guard and leave training static. Exercise changes and leaving/pausing training remove that action.
- Core tremor is applied after action evaluation using bounded absolute offsets, with alternating brace/rest phases and no accumulated drift. Added distinct lowered-chest and closed-eye exhale plank frames for all three breeds; bird dog keeps its reaching frames.
- Larger outlined cyan/white sweat droplets start within the first second and appear briefly every 3.2–4.8 seconds for core training. They disappear between bursts and are removed on pause/finish. Reduce Motion uses changing effort drawings and a fading stationary bead, without shaking or particle flight.
- CoreEffortRegression passes for phase variation, bounded offsets, no drift and reduced-motion behavior. StrengthRegression passes with new frame geometry/distinction coverage across three breeds and all growth stages. Live SE3 side-plank captures show different effort poses and airborne sweat; pause returns to idle. Discarded the verification session without saving. Evidence: Design/CoreEffortReview/.
- Final Debug app/widget build and whitespace checks pass. `Design/CoreEffortReview/core-effort.gif` is cropped from the live simulator captures.

## 2026-10-24 — Grounded forepaws for crunch; remove sweat
- Replaced crunch's stretching frames with the existing planted-paw plank/brace frames, so the chest lowers slightly while the paw tips stay on the floor; there is no forward-reaching foreleg pose.
- Removed the workout sweat renderer, scheduling state and update hook entirely for all exercises. Core trembling and brace/release poses remain.
- Debug app/widget build and whitespace checks pass. Live SE3 UI confirms the grounded crunch posture; verification session discarded without recording. Confirmed no sweat references remain in app Swift sources.

## 2026-10-25 — Grounded hip lift
- Replaced hip lift's forward-reaching stretch poses with the existing low-haunch/standing poses. Both keep the head and front-paw stance fixed while the hindquarters lower and lift, with a brief hold at the top. No supine poses or sweat effects.
- Debug app/widget build and whitespace validation pass.

## 2026-10-25 — Widget workout shortcuts
- Reworked the small widget around a single recent-exercise start action, and the medium widget around three direct exercise links with pixel icons and saved reps/time. The dog and chosen name remain visible. Active workouts show a return action using the original session snapshot.
- Added shared recent-choice ordering, preserved custom exercise targets/titles, an empty-list fallback to the home picker, and a registered workout URL scheme. Opening a shortcut selects Home and starts the saved preset directly; an existing running/paused session is preserved. Preset edits and workout starts refresh the widget.
- WidgetRegression passes with route encoding/validation, recent ordering/deduplication, edited/custom targets, empty lists, active-session snapshots, all breed/coat combinations and sprite-asset coverage. All widget translations and app plist validate.
- Final Debug app/widget builds pass, including an ad-hoc-signed simulator build with working shared-group entitlements. Preserved existing QA settings when moving from the earlier unsigned installation's isolated preferences into the simulator's shared group.
- Actual SE3 home screen: small-widget tap starts 10-rep squat directly; medium widget shows まめ and the saved 6-second plank. A cold tap starts that timed workout immediately; tapping another shortcut while it awaits saving returns to the existing plank without overwriting it. Discarded verification sessions without recording. Screenshot: Design/WidgetQuickStartReview/medium-widget.png. No App Store upload.

## 2026-10-25 — Read-only submission-readiness audit
- Current Release device build succeeds without diagnostics (.build/review-readiness-release-build.log), but its version/build remain 1.04 (64), predating the new strength-focused submission packaging.
- Read App Store Connect in the existing signed-in Safari session: iOS 1.04 is Ready for Distribution (配信準備完了), with the old habit-tracker description/review notes. Existing non-consumable promise_timer.premium.lifetime / 6825802653 is Approved. No remote fields changed, no upload or submission performed.
- The strength-focused release needs a new version/build, current screenshots and five-locale metadata. Existing October 22 store assets/copy describe reading, meals and weekly habit targets.
- No app-owned PrivacyInfo.xcprivacy exists in either app or widget sources; the built app contains only the Google SDK manifests. Own UserDefaults/AppStorage and App Group access require an app/extension required-reason declaration (Apple TN3183 and UserDefaults reason documentation).
- The in-app privacy policy URL opens successfully, but still names the app 1分できたログ and describes third-party ads/analytics as future plans, while the current app already uses AdMob. Update the published policy and reconcile App Store privacy disclosures before submission.
- Latest actual-device purchase/restore and final device/widget verification remain unconfirmed; simulator/local StoreKit checks do not establish those outcomes. No real purchase attempted.

## 2026-10-25 — Strength release submission in progress
- User explicitly authorized completing prep and App Review submission; approved names ja ぽちと筋トレ, en Workout with Pochi, ko 포치랑 운동, both Chinese 和波奇一起健身.
- App/widget localized display names, in-app Premium/branding translations updated. Both targets now 1.05 (65).
- Added app and widget own PrivacyInfo.xcprivacy UserDefaults CA92.1/1C8F.1. Added UMP launch consent gathering, ad-request gating, error/offline fallback to prior valid consent, and required privacy-options entry in Settings. Added accessible policy link in Settings. Ads suppressed without valid SDK consent; workout remains usable. ATT remains optional. SDKs unchanged (GMA12.14, UMP3.1).
- Clean signed Debug simulator build and signed Release archive pass. Archive .build/PochiWorkout-1.05-65.xcarchive contains matching app/widget versions and own manifests. Uploaded successfully using .build/strength-release-upload.log; only vendor dSYM warnings (same as prior release). Build processing on ASC needs checking/attachment.
- WidgetRegression, TogetherRegression, WorkoutSoundRegression, CoreEffortRegression, WorkoutCatalogRegression all pass.
- Published updated Japanese/English privacy policy in existing public GitHub repo via UI, commit c3c9032523a2f3deb609fbe3592f0eafa69282a3. Local copy Design/AppStore/2026-10-25/privacy_policy.txt; screenshot privacy-policy-published.png. Same policy URL retained.
- Created ASC iOS1.05 draft. Entered five locales' strength-focused description/promo/release notes/keywords and removed invalid app-ads.txt marketing URL (re-read all locales before final submit). Review notes updated for workout semantics and approved lifetime product.
- App Info names/subtitles changed in all five locales; primary category changed Lifestyle→Health/Fitness. Re-read/save proof before submission. Medical-device declaration now available, not yet answered; reminder says due early2027.
- ASC current page /apps/6760613210/distribution/privacy. Existing obsolete disclosure includes userID/deviceID/adData/otherUsage, tracking and unlinked. Needs reconcile with bundled GMA manifest: 7 types coarseLocation/deviceID/adData/productInteraction/crash/performance/otherDiagnostics; no app-server collection of workout data.
- NEW disposable screenshot sim Pochi Workout Store, iPhone16ProMax/iOS18.5 UUID 0F456FD8-8D8E-4ACE-9DB7-1620D25656E3, booted, signedDebug installed, statusbar9:41. Onboarding real UI completed, default nameぽち. Saved squat/plank test records ONLY on this dedicated disposable simulator. ATT denied to confirm usable workflow. Current locale English, active plank30sec. Other original QA/user devices untouched.
- New screenshot folder Design/AppStore/2026-10-25. listing.json five locales finalized lengths checked (en keywords fixed under100). Raw ja-home/reps/timer/profile/onboarding done; en-US-home/reps/timer done (need profile/onboarding); remaining3locales not captured. Planned five screens perlocale home/reps/timer/profile/onboarding, no fake records. New compositor scripts/render_workout_store_screenshots.swift uses this root and five screen names, headings indices0,1,2,4,5.
- Native CUA Device Hub AX clicks work; coordinate clicks return noWindowsAvailable even after Raise, compact switch, reacquire. Screenshots sometimes need performSecondaryAction(0,Raise), native AX state may be stale until disableDiffing. Compact window now710x1572, bindingworkoutHub. Profile grabber AX click expands sheet. Avoid coords; use AX buttons. CUA Safari AX works, including clicks/paste; re-read IDs after async saves. Save status must read Saved/disabled rather than just assuming click.
- User unlocked Mac after first outage; no further confirmation needed. Safari bound reviewSafari current ASC privacy; IAB reviewTab tab2 currently published GitHub policy. releaseFS (node:fs/promises), releaseListing, releasePolicy bound in CUA for prepared local copy insertion. IAB created tabs close on final unless mark; must keep if pausing.
- Remaining: finish screenshots five locales and render/visual QA; detach inherited old draft assets recoverably then upload new sets; verify all metadata and names; reconcile ASC privacy; attach build65/export compliance if needed; optional update old IAP localized titles/review notes to new brand; final review submission and verify Waiting for Review. User explicitly requested submission, no need ask again except genuine action-time legal agreement/attestation requirement.
- User explicitly approved publishing all 7 SDK data disclosures in async reply. Auto-review block resolved by that approval. Privacy types published; new location/productInteraction/crash/performance/otherDiagnostics detailed purposes/link/tracking completed. Location/product linked yes, tracking no; diagnostics linked no/tracking no; crash analytics only; others third-party ads + analytics. Existing deviceID updated linked yes/tracking yes and ad+analytics. Existing Advertising Data edit wizard currently OPEN at purposes, needs analytics added and linked yes/tracking no; then publish. All current choices follow bundled SDK manifest (developer advertising purpose omitted because app does not run own marketing).
- Five real screenshots per locale now raw captured for ALL 5 locales: home/reps/timer/profile/onboarding. Composer rerun pending/completing .build/render-workout-store-screenshots (session at latest tool output). Japanese and English five uploaded to NEW draft large Dynamic Island iPhone set. Old sets detached recoverably (remain asset library). Korean/Chinese sets still inherited old six and need replacement. Final render and contact-sheet visual QA needed; no raw image faking. Store screenshots omit SDK test creative through existing DEBUG flag.
- Safari has 3 tabs: first unrelated GitHub, second ASC privacy (currently selected, AdData wizard), third ASC new1.05 media manager (English large set newly uploaded). To switch between ASC tabs via UI, releaseClick(reviewSafari,/タブ App Store Connect, Value: off/) picks only other ASC tab.
- CUA helpers persist: releaseClick(app, regex, ordinal=0) refreshes full AX then clicks matching index, returns AX diff. releaseUpload(locale) opens large Dynamic Island section, chooses SECOND exact button Upload (first is medium slot), uses native file picker GoToWindow PathTextField, setValue folder then Return, selects first row then shift-clicks last row, verifies five files, uploads. Keyboard Cmd+A does not select all file rows; shift-click DOES. Wait for asynchronous page save after navigation before relying on IDs; releaseClick avoids stale IDs. Large section collapses on locale change.
- CUA releasePrivacyConfigure(type,linked,tracking,advertising=true) handles blue setup entry through purpose/linking/3 tracking info pages/final radio/Publish. releasePrivacyDetails(linked,tracking) handles CURRENT existing-type edit wizard, adds analytics, then link/tracking/publish; currently ready to call (true,false) for AdData. User approval covers all exact SDK disclosures. Details helper assumes current ad checkbox already true. Need inspect final overview for no outstanding setup.
- Native Device Hub coordinate clicks consistently noWindowsAvailable (even if screenshots and AX work), use AX buttons. CompactworkoutHub. Profile sheet grabber expands via AX. Current dedicated sim locale zh-Hant, DEBUG review onboarding at step2. Workout reps and timed saves verified by real UI in every locale; no real phone touched. Build65 uploaded successfully; processing/attachment still needs ASC check.
- ASC privacy 7-type disclosures are now fully published, no outstanding setup. Published summary tracking=ID; linked=ID/Usage/Location; unlinked=Diagnostics. Proof privacy-disclosures-published.png. User action-time approval recorded in chat.
- Korean and Simplified Chinese five images uploaded and count verified. Traditional Chinese upload succeeded, count not yet re-verified. All 25 local screenshots rendered and visually inspected as contact-*.png. English timer raw shows ended/manual-save state; local en headline3 changed to Finish your plank / Save with one tap to match. English local recomposed images therefore need re-upload (recoverable detach old5 first); other locales current.
- Created and booted disposable Pochi Workout Store iPad iPadPro13M4/iOS18.5 UUID38003860-A922-449C-BDCE-B0733D99A08E; signedDebug installed; statusbar9:41; app started in Japanese first onboarding screen. DeviceHub selected iPad in MAIN window. App not onboarded yet, no iPad screenshots yet.
- Attached build65 to ASC1.05 and saved. Current second Safari tab is 1.05 version main page, build65 selected, Missing Compliance. Cell 管理 is AXselectable; clicking cell only selected it and did not open compliance questionnaire. Need screenshot/click actual link once Mac UI resumes. Save disabled confirms persisted. Existing automatic release and retain ratings unchanged.
- Third Safari tab is zh-Hant media manager, upload completed. First tab unrelated GitHub. Privacy now completed so secondtab can be used forversion/AppInfo/IAP.
- CUA screenshot timed out and reset runtime twice; current bindings AFTER LAST RESET: only reviewSafari, workoutHub (main iPad), releaseFS and releaseClick, releaseDetach, releaseUpload exist (latest reset recreated first3 helpers and uploads); no releaseListing or privacy helpers. Last tool getScreenshot timed out then kernel reset, so ACTUALLY no bindings until reacquire! Reinitialize exactly one entrypoint on first call afterreset. New async question asks user to unlock Mac/keep Safari operable because screen acquisition repeatedlytimesout; response still pending. Native AX often works while coordinate/screenshot don't; do not assume physicalphone changes.
- Submission NOT completed yet. Remaining: finalHant count/proof; re-uploadEnglish captionrevision; verify all5 metadata/names/subtitles fromASC; iPad screenshot requirementcheck/capture ifneeded; exportcompliance answer (previous64userapprovednone, new65mightneedfreshaction-timeapproval); optional approvedIAPtitlelocalizationsupdate; final AddtoReview/Submit/verifyWaitingforReview.
- MarketingURL earlier removed old app-ads.txt URL all5locales. Reconsider beforefinal: GoogleAdMob uses AppStore Developer Website/marketingURL domain forapp-ads.txt verification; preservingpriorapprovedURL may be better than removing since no separatelandingpageexists. Needprimarydocsverify and restore existingURL if appropriate, without inventing a newwebsite.
- Export compliance user explicitly approved new65 same None answer. Opened actual questionnaire through TestFlight table's Manage link via screenshot-grounded coordinate click (AXcellonlyselected, noaction). SelectedNone; active Save was AXrole リンク notボタン. Saved viaリンク保存; questionnaireclosed and MissingCompliance labeldisappeared inTestFlight65row. Needversionpagefinalverify.
- Safari screenshot workaround: performSecondaryAction(0,Raise) BEFORE getScreenshot. This restored capture; earlier timeouts may have been backgroundwindow focus ratherthanlock. CoordinateSafari clickworks; DeviceHubcoordstillfails. No needrepeatunlockquestion (oneasyncunlockquestionmaystillpending, butworkresumed).
- iPad13 store requiredslotwas0screenshot, oldghostassetsdisplayed (inspectoptional12.9foroldexplicitassetsbeforefinal). NewactualiPad2064x2752screenscapturedall5locale at ipad/{locale}/01-home.png. RealUIonboardingcompleted; eachHomeSquatselectedviaAX. CurrentdedicatediPadappzh-HantHome, no testrecordsadded. Uploaded iPad13 ja/en-US oneeach; remainingko/Hans/Hantnotyetuploaded. CurrentthirdSafari tab iPadmediaEnglish, enuploadjustcompleted. CurrentsecondtabTestFlight65withcomplianceresolved.
- CUA currentbindings: reviewSafari, workoutHub(mainiPad), releaseFS, releaseClick, releaseLocale(name), releaseUploadIpad(locale). Otheroldhelpersabsentafterlastreset, mustredefineiPhoneDetach/UploadbeforeEnglishre-upload. releaseLocaleusesfreshAXlocalepickerandmenu option(regexselectedprefix optional), worksmediaandlikelyAppInfo/version. NativefilepickerGoToWindowpathmustsetValue, observe, Return, observe; selectingonefullpathworksipadhelper. ScreenshotproofalwaysRaisefirst.
- iPhone25imagesalluploaded/verifiedfiveincludingHant; enheadlinechangedlocally afterinitialupload(stillneedre-uploadallEnglish5). All25contactsheetvisualQApassed. NeedcurrentEnglishlocalcaption3UploadFinishplankmatchesendedstateorretakerealtimeEnglish3thenrender/upload. Keepactualscreenshonest.

### 2026-10-25 09:55 JST — App Store review submitted
- User approved export compliance answer “None of the algorithms listed”; saved for 1.05 (65).
- App version 1.05 (65) and existing lifetime IAP localized name updates submitted together.
- Verified both items WAITING FOR REVIEW in App Store Connect. Submission ID: 35b51fef-a2a9-42e0-87f1-b3c826e666b4.
- Automatic release after approval retained. Five localized listings and phone/iPad screenshots complete; privacy declarations published with explicit user approval.
- Proof and machine-readable receipt: Design/AppStore/2026-10-25/submission-waiting-for-review.png and submission.json.
