# ならぶ

仮想の行列に、ただ並び続けるだけのiOSアプリです。何の列なのかは最後まで説明しません。

## コンセプト

実用性はありません。開くと自分の並び順が表示され、アプリを閉じている間も列は進みます。
2週間ほど並ぶと先頭にたどり着き、何の値打ちもない景品を受け取って、また最後尾に戻ります。

「意味がないのに気になって開いてしまう」ことだけを狙って作っています。

## 仕組み

- **列の進行**: 位置は保存せず、基準時刻からの経過時間だけで毎回計算します（`QueueEngine`）。
  時間帯ごとに進みかたが変わり、深夜はほとんど進みません。同じ入力には必ず同じ結果を返すため、
  未来の位置を先読みして通知を予約できます。
- **割り込み**: ときどき、課金して割り込んでくる人がいます。並び順が戻り、通知が届きます。
- **景色**: 先頭に近づくと景色が段階的に変わります（`QueueScenery`）。
  遠くの建物が見え、やがて屋根の下に入り、窓口の明かりが見えてきます。
- **前後の人**: 並び順から決定的に生成されます（`NeighborGenerator`）。大きく進むと顔ぶれが入れ替わります。
- **景品**: 先頭で受け取った景品は通し番号入りの整理券とともに図鑑に記録されます。
  周回ごとに受け取る品は決まっており、引き直しはできません。

## 収益化

消耗型App内課金で「100人抜かす」を販売します（Product ID: `io.github.supamucho76wq.narabu.skip100`）。
意味のない行列を、お金を払って進むという設計そのものがネタです。開発ビルドでは課金なしで動作します。

## 開発環境

- Xcode 26以降 / Swift 6 / iOS 17以降
- SwiftUI / StoreKit 2 / UserNotifications

このリポジトリはWindows上で生成しているため、最終ビルドと実機テストはmacOS上のXcodeで行います。

## Macでの開始手順

1. XcodeGenをインストールします。
2. このディレクトリで `xcodegen generate` を実行します。
3. `Narabu.xcodeproj` をXcodeで開きます。
4. Signing & CapabilitiesでTeamとBundle Identifierを設定します。
5. 実機を選択してビルドします。

## WindowsからCodemagicで検証

`codemagic.yaml` の `ios-validate` ワークフローが、CodemagicのmacOS上でXcodeGenを実行し、
署名なしのSimulatorビルドとユニットテスト、起動時スクリーンショットの取得までを行います。

## 未完了の外部設定

- ~~App Store Connectのアプリ登録~~ 完了（Bundle ID: `io.github.supamucho76wq.narabu`）
- ~~Apple Developer Team・署名設定~~ 完了（Codemagicの`code-signing`グループに`CERTIFICATE_PRIVATE_KEY`を登録）
- ~~アプリアイコン~~ 完了（1024pxを1枚。行列を上から見た図で、最後尾の赤が自分）
- 消耗型商品「100人抜かす」の登録（¥160想定、Product ID: `io.github.supamucho76wq.narabu.skip100`）
- プライバシーポリシー・サポートURLの公開

## 今後の予定

現在は端末内で行列をシミュレートしています。反応を見たうえで、全ユーザーが同じ列に並ぶ
本物の共有行列（Supabase等）に差し替える想定です。
