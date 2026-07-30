import Foundation

/// 列の中で起きる出来事。選びかたで結果が変わる。
struct QueueEvent: Identifiable, Equatable, Sendable {
    struct Choice: Equatable, Sendable {
        let label: String
        /// 選んだ結果の言葉。
        let result: String
        /// 進む人数。負なら後退。
        let advance: Int
        let coins: Int
        /// 手に入るアイテム。
        let itemID: String?
    }

    let id: UUID
    let title: String
    let situation: String
    let symbolName: String
    let choices: [Choice]
}

enum QueueEventFactory {
    /// 何回行動するごとに出来事が起きるか。
    static let actionsPerEvent = 12

    /// 進むほど揺れ幅が大きくなるよう、ステージの人数を基準にする。
    static func make(seed: Int, stage: Stage) -> QueueEvent {
        let scale = max(2, stage.queueLength / 40)
        let templates = templates(scale: scale)
        let index = Int(QueueEngine.unitRandom(seed, salt: 0x2E90) * Double(templates.count))
        return templates[min(index, templates.count - 1)]
    }

    private static func templates(scale: Int) -> [QueueEvent] {
        [
            QueueEvent(
                id: UUID(),
                title: "整理券が配られた",
                situation: "店員が列の後ろから整理券を配り始めた。前のほうはもう配り終わっている。",
                symbolName: "ticket",
                choices: [
                    .init(label: "受け取りに戻る", result: "整理券をもらえた。列の順番は変わらないが、余分にもらえた。",
                          advance: 0, coins: 60, itemID: "dash"),
                    .init(label: "無視して前を向く", result: "配り終わってしまった。少しだけ列が詰まった。",
                          advance: scale, coins: 0, itemID: nil)
                ]
            ),
            QueueEvent(
                id: UUID(),
                title: "割り込み客",
                situation: "堂々と割り込んできた人がいる。周りは見て見ぬふりをしている。",
                symbolName: "person.fill.badge.minus",
                choices: [
                    .init(label: "最後尾を教える", result: "素直に最後尾へ歩いていった。周りに感謝された。",
                          advance: scale, coins: 40, itemID: nil),
                    .init(label: "黙っておく", result: "そのまま前に入られた。1人ぶん下がった。",
                          advance: -1, coins: 0, itemID: nil),
                    .init(label: "自分も便乗する", result: "後ろ全員に睨まれた。気まずくて下がった。",
                          advance: -2, coins: 20, itemID: nil)
                ]
            ),
            QueueEvent(
                id: UUID(),
                title: "雨が降ってきた",
                situation: "急に雨。傘を持っていない人がざわつき始めた。",
                symbolName: "cloud.rain",
                choices: [
                    .init(label: "傘を貸す", result: "喜ばれた。前に入れてもらえた。",
                          advance: scale * 2, coins: 0, itemID: nil),
                    .init(label: "自分だけしのぐ", result: "濡れずに済んだ。何も起きなかった。",
                          advance: 0, coins: 30, itemID: nil)
                ]
            ),
            QueueEvent(
                id: UUID(),
                title: "有名人が現れた",
                situation: "向かいの通りに有名人が来たらしい。何人かが列を離れて走っていく。",
                symbolName: "sparkles",
                choices: [
                    .init(label: "列に残る", result: "抜けた人のぶんだけ、まとめて前に詰めた。",
                          advance: scale * 3, coins: 0, itemID: nil),
                    .init(label: "自分も見に行く", result: "戻ってきたら少し後ろになっていた。写真は撮れた。",
                          advance: -2, coins: 80, itemID: nil)
                ]
            ),
            QueueEvent(
                id: UUID(),
                title: "新しい列が開いた",
                situation: "隣に別の窓口が開いた。何人かがそちらへ移り始めている。",
                symbolName: "arrow.triangle.branch",
                choices: [
                    .init(label: "移る", result: "移った先も混んでいた。差し引きで少しだけ得をした。",
                          advance: scale, coins: 0, itemID: nil),
                    .init(label: "動かない", result: "移った人のぶん、この列が空いた。",
                          advance: scale * 2, coins: 0, itemID: nil)
                ]
            ),
            QueueEvent(
                id: UUID(),
                title: "近道を知っている人",
                situation: "「こっちから回ると早いですよ」と教えてくれる人がいる。本当かは分からない。",
                symbolName: "map",
                choices: [
                    .init(label: "教わったとおりに動く", result: "本当に近道だった。かなり前に出られた。",
                          advance: scale * 4, coins: 0, itemID: nil),
                    .init(label: "怪しいのでやめる", result: "後で見たら、その人は元の場所に戻っていた。",
                          advance: 0, coins: 50, itemID: nil)
                ]
            ),
            QueueEvent(
                id: UUID(),
                title: "前方でトラブル",
                situation: "前のほうで言い争いが起きて、列が止まっている。",
                symbolName: "exclamationmark.triangle",
                choices: [
                    .init(label: "仲裁に入る", result: "言い争いは収まった。当事者の両方から礼を言われ、前に通してもらえた。",
                          advance: scale * 2, coins: 40, itemID: nil),
                    .init(label: "関わらない", result: "しばらくして自然に収まった。",
                          advance: 0, coins: 10, itemID: nil)
                ]
            ),
            QueueEvent(
                id: UUID(),
                title: "友人が合流したがっている",
                situation: "知り合いが後ろから声をかけてきた。ここに入れてほしいらしい。",
                symbolName: "person.2",
                choices: [
                    .init(label: "入れてあげる", result: "後ろの人に文句を言われ、まとめて下がった。",
                          advance: -2, coins: 0, itemID: "bicycle"),
                    .init(label: "断る", result: "気まずいが、列の秩序は守られた。周りが少し詰めてくれた。",
                          advance: scale, coins: 20, itemID: nil)
                ]
            ),
            QueueEvent(
                id: UUID(),
                title: "売り切れの噂",
                situation: "「もうすぐ売り切れるらしい」という声が後ろから流れてきた。",
                symbolName: "flame",
                choices: [
                    .init(label: "急いで前に詰める", result: "みんなが動いたので、うまく紛れて前に出られた。",
                          advance: scale * 2, coins: 0, itemID: nil),
                    .init(label: "デマだと判断する", result: "実際デマだった。慌てた人が抜けたぶん進んだ。",
                          advance: scale, coins: 60, itemID: nil)
                ]
            ),
            QueueEvent(
                id: UUID(),
                title: "落とし物",
                situation: "足元に財布が落ちている。少し前の人のものらしい。",
                symbolName: "bag",
                choices: [
                    .init(label: "届ける", result: "お礼にと、前に入れてもらえた。",
                          advance: scale * 3, coins: 0, itemID: nil),
                    .init(label: "店員に渡す", result: "正しい対応だった。落ち着いて列に戻った。",
                          advance: 0, coins: 90, itemID: nil),
                    .init(label: "見なかったことにする", result: "後で持ち主に気づかれ、周りの空気が悪くなった。",
                          advance: -1, coins: 0, itemID: nil)
                ]
            )
        ]
    }
}
