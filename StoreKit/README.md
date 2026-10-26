# 実機でプレミアムを確認する

1. Xcodeで `promise_timer` スキームと接続したiPhoneを選び、▶（⌘R）で起動します。
2. アプリの「設定 → プレミアム → 買い切りで購入」を押します。
3. テスト購入を確定し、広告枠の消失、追加2犬種、再起動後の購入状態、「購入を復元」を確認します。

通常のRun（Debug）に `PochiPremium.storekit` を設定済みです。日本向け3,900円・買い切り1商品のローカルテストで、実際の請求はありません。実機での購入操作はまだ未確認です。

再度購入前から試す場合は、Xcodeの **Debug → StoreKit → Manage Transactions** で、このアプリのローカルテスト取引だけを削除します。習慣データを消したり、アプリを削除したりする必要はありません。

AppleサーバーのSandbox確認へ切り替える場合は、Edit Scheme → Run → Options → StoreKit Configuration を None にします。

このファイルはアプリのリソースに含めていません。テスト設定はスキームのLaunchActionのみで、Archive/Releaseの商品ID・検証・課金処理は変えていません。審査中の1.04(64)にも変更はありません。
