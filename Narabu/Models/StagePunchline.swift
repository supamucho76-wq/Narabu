import Foundation

/// 先頭にたどり着いたあとの、短いオチ。
///
/// **先頭に着いて終わるだけでは弱い。**
/// あれだけ抜いてきた末に「本日定休日」と言われる。この裏切りがあるから、
/// 次のステージで何を言われるのかが気になる。
///
/// 台詞は1行だけ。読ませるものではなく、落とすためのもの。
struct StagePunchline: Equatable, Sendable {
    /// 大きく出す一言。
    let headline: String
    /// その下に小さく添える説明。
    let detail: String
    /// 添えるSF Symbol。
    let symbolName: String
}

enum PunchlineCatalog {
    /// どのステージでも起こりうるオチ。
    ///
    /// 行列というものは、たどり着いたところで報われるとは限らない。
    private static let common: [StagePunchline] = [
        StagePunchline(
            headline: "本日定休日",
            detail: "貼り紙は、いちばん後ろからは見えなかった。",
            symbolName: "xmark.seal.fill"
        ),
        StagePunchline(
            headline: "売り切れました",
            detail: "目の前で札が裏返された。",
            symbolName: "tray.fill"
        ),
        StagePunchline(
            headline: "財布を忘れた",
            detail: "ポケットには整理券だけが入っていた。",
            symbolName: "creditcard.trianglebadge.exclamationmark"
        ),
        StagePunchline(
            headline: "整理券が必要でした",
            detail: "配っていたのは、3時間前の話だそうだ。",
            symbolName: "ticket.fill"
        ),
        StagePunchline(
            headline: "並ぶ列を間違えていた",
            detail: "隣の列が、本当の列だった。",
            symbolName: "arrow.triangle.branch"
        ),
        StagePunchline(
            headline: "最後尾へお戻りください",
            detail: "抜いてきたのが、全部見られていた。",
            symbolName: "arrow.uturn.backward"
        ),
        StagePunchline(
            headline: "無料ティッシュの列だった",
            detail: "ひとり1個まで。",
            symbolName: "gift.fill"
        ),
        StagePunchline(
            headline: "味は普通だった",
            detail: "並んだ時間のことは、もう考えないことにした。",
            symbolName: "face.smiling"
        ),
        StagePunchline(
            headline: "先頭にいたのは元恋人だった",
            detail: "目が合った。何も言わずに列を出た。",
            symbolName: "heart.slash.fill"
        ),
        StagePunchline(
            headline: "自分が店員だった",
            detail: "厨房から呼ばれている。今日は遅番だった。",
            symbolName: "person.badge.key.fill"
        )
    ]

    /// ステージらしいオチ。共通のものより先に選ばれやすい。
    private static func special(for stage: Stage) -> [StagePunchline] {
        switch stage.id {
        case 1:
            return [
                StagePunchline(
                    headline: "レジ袋は5円です",
                    detail: "小銭がない。後ろの列が伸びていく。",
                    symbolName: "bag.fill"
                )
            ]
        case 2, 7:
            return [
                StagePunchline(
                    headline: "本日のスープ、終了しました",
                    detail: "暖簾は、目の前でしまわれた。",
                    symbolName: "takeoutbag.and.cup.and.straw.fill"
                ),
                StagePunchline(
                    headline: "隣の店のほうが美味い",
                    detail: "前の人がそう言って、列を出ていった。",
                    symbolName: "arrow.turn.up.right"
                )
            ]
        case 3:
            return [
                StagePunchline(
                    headline: "限定ドリンクは終了しました",
                    detail: "代わりにホットの普通のやつを勧められた。",
                    symbolName: "cup.and.saucer.fill"
                )
            ]
        case 4:
            return [
                StagePunchline(
                    headline: "点検のため運休",
                    detail: "150分並んだ先にあったのは、看板だけだった。",
                    symbolName: "wrench.and.screwdriver.fill"
                )
            ]
        case 5:
            return [
                StagePunchline(
                    headline: "開演は明日でした",
                    detail: "チケットの日付を、いま初めてよく見た。",
                    symbolName: "calendar.badge.exclamationmark"
                )
            ]
        case 6:
            return [
                StagePunchline(
                    headline: "お目当ては完売",
                    detail: "前の人が最後の1冊を抱えている。",
                    symbolName: "book.closed.fill"
                )
            ]
        case 8:
            return [
                StagePunchline(
                    headline: "サイズがなかった",
                    detail: "残っていたのは18センチと31センチだけだった。",
                    symbolName: "shoe.fill"
                ),
                StagePunchline(
                    headline: "抽選販売でした",
                    detail: "3日間、並ぶ必要はまったくなかった。",
                    symbolName: "dice.fill"
                )
            ]
        case 9:
            return [
                StagePunchline(
                    headline: "搭乗口が変更になりました",
                    detail: "反対側の端。走っても15分かかる。",
                    symbolName: "airplane.departure"
                ),
                StagePunchline(
                    headline: "ポケットに小銭が残っていた",
                    detail: "最初からやり直しです。",
                    symbolName: "arrow.counterclockwise"
                )
            ]
        case 10:
            return [
                StagePunchline(
                    headline: "紙がありませんでした",
                    detail: "標高3776メートル。誰も持っていなかった。",
                    symbolName: "wind"
                ),
                StagePunchline(
                    headline: "もう我慢できなくなっていた",
                    detail: "並んでいる途中で、なんとかなってしまった。",
                    symbolName: "hare.fill"
                )
            ]
        case 11:
            return [
                StagePunchline(
                    headline: "パスポートは地球に忘れた",
                    detail: "取りに戻ると、次の便は120年後になる。",
                    symbolName: "globe.asia.australia.fill"
                ),
                StagePunchline(
                    headline: "行き先は火星でした",
                    detail: "そこにも行列があるらしい。",
                    symbolName: "circle.hexagonpath.fill"
                )
            ]
        case 12:
            return [
                StagePunchline(
                    headline: "審査の結果、差し戻し",
                    detail: "生前の列抜かしが、全部記録に残っていた。",
                    symbolName: "doc.text.magnifyingglass"
                ),
                StagePunchline(
                    headline: "本日の受付は終了しました",
                    detail: "また明日。明日がいつなのかは教えてもらえなかった。",
                    symbolName: "moon.stars.fill"
                )
            ]
        case 13:
            return [
                StagePunchline(
                    headline: "次は「並んでいる人」です",
                    detail: "希望は通らなかった。",
                    symbolName: "arrow.triangle.2.circlepath"
                ),
                StagePunchline(
                    headline: "番号札をもう1枚渡された",
                    detail: "こちらの列にもお並びください、とのことだった。",
                    symbolName: "ticket.fill"
                )
            ]
        case 14:
            return [
                StagePunchline(
                    headline: "ダウンロード版が出ていた",
                    detail: "並ばずに買えたらしい。しかも半額。",
                    symbolName: "arrow.down.circle.fill"
                ),
                StagePunchline(
                    headline: "起動したら、また最後尾だった",
                    detail: "画面の中の自分が、こちらを見た気がした。",
                    symbolName: "iphone.gen3"
                )
            ]
        default:
            return []
        }
    }

    /// このステージで出るオチをひとつ選ぶ。
    ///
    /// - Parameter seed: 同じクリアでは同じオチになるようにするための種。
    static func punchline(for stage: Stage, seed: Int) -> StagePunchline {
        let candidates = special(for: stage) + common
        guard !candidates.isEmpty else {
            return common[0]
        }

        let index = Int(QueueEngine.unitRandom(seed, salt: 0x0C1E) * Double(candidates.count))
        return candidates[min(index, candidates.count - 1)]
    }
}
