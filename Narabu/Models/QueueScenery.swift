import Foundation

/// 並んでいる場所から見える景色。先頭に近づくほど、窓口の気配が濃くなっていく。
///
/// 何の列なのかは最後まで説明しないが、景色だけは着実に変わる。
struct QueueScenery: Equatable, Sendable {
    /// この景色が始まる並び順。
    let fromPosition: Int
    let title: String
    /// 目の前に見えているもの。
    let description: String
    /// 空の色。position が小さいほど、屋根の下に入って暗くなる。
    let skyTone: Double
    /// 屋内に入ったかどうか。天気の影響を受けなくなる。
    let isSheltered: Bool

    static let stages: [QueueScenery] = [
        QueueScenery(
            fromPosition: 6_000,
            title: "見わたすかぎりの背中",
            description: "前にも後ろにも人が続いている。列の先がどこへ向かっているのかは見えない。",
            skyTone: 1.0,
            isSheltered: false
        ),
        QueueScenery(
            fromPosition: 4_000,
            title: "遠くの影",
            description: "ずっと先に、建物のようなものの影がある。まだ形はわからない。",
            skyTone: 0.96,
            isSheltered: false
        ),
        QueueScenery(
            fromPosition: 2_500,
            title: "建物の輪郭",
            description: "灰色の低い建物が見えてきた。窓はなく、入口らしきものが一つだけある。",
            skyTone: 0.9,
            isSheltered: false
        ),
        QueueScenery(
            fromPosition: 1_200,
            title: "敷地の中",
            description: "白線で仕切られた通路に入った。等間隔にポールが立っている。",
            skyTone: 0.84,
            isSheltered: false
        ),
        QueueScenery(
            fromPosition: 500,
            title: "屋根の下",
            description: "屋根に入った。雨の音が遠くなり、蛍光灯の音が聞こえる。",
            skyTone: 0.62,
            isSheltered: true
        ),
        QueueScenery(
            fromPosition: 150,
            title: "窓口の明かり",
            description: "廊下の先に、明かりのついた窓口が見える。人が一人で座っている。",
            skyTone: 0.5,
            isSheltered: true
        ),
        QueueScenery(
            fromPosition: 30,
            title: "声の届く距離",
            description: "窓口の人が何か話しているのが聞こえる。内容までは聞き取れない。",
            skyTone: 0.42,
            isSheltered: true
        ),
        QueueScenery(
            fromPosition: 1,
            title: "あと少し",
            description: "前の人が窓口で何かを受け取っている。こちらを振り返らずに帰っていく。",
            skyTone: 0.38,
            isSheltered: true
        ),
        QueueScenery(
            fromPosition: 0,
            title: "先頭",
            description: "窓口の人がこちらを見て、小さくうなずいた。",
            skyTone: 0.34,
            isSheltered: true
        )
    ]

    static func current(for position: Int) -> QueueScenery {
        stages.first { position >= $0.fromPosition } ?? stages[0]
    }

    /// 次の景色に変わるまでの残り人数。0 なら先頭。
    static func peopleUntilNextStage(from position: Int) -> Int? {
        guard let index = stages.firstIndex(where: { position >= $0.fromPosition }),
              index + 1 < stages.count else { return nil }
        return position - stages[index + 1].fromPosition
    }
}
