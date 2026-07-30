import Foundation

/// 前の人を叩いたときに起きること。
struct TapOutcome: Equatable {
    let message: String
    /// 前の人が列を抜けて、1人ぶん進んだかどうか。
    let didAdvance: Bool
}

/// 前の人の反応。叩いた回数が増えるほど、態度が悪くなっていく。
enum TapReactions {
    /// 叩かれた人が列を抜けてしまう確率。
    private static let departureProbability = 0.02

    private static let firstReactions = [
        "前の人が振り返った。",
        "前の人が少し前に詰めた。",
        "前の人が会釈した。",
        "前の人が肩を払った。",
        "前の人が時計を見た。"
    ]

    private static let annoyedReactions = [
        "前の人が眉をひそめている。",
        "前の人が半歩だけ距離を取った。",
        "前の人が小さくため息をついた。",
        "前の人がこちらを見ずに首を振った。",
        "前の人が荷物を持ち替えた。"
    ]

    private static let coldReactions = [
        "前の人はもう振り返らない。",
        "前の人があなたを覚えたようだ。",
        "前の人が黙って前を見ている。",
        "前の人が後ろの人に何か言った。",
        "前の人は反応しなくなった。"
    ]

    private static let departureMessages = [
        "前の人が列を抜けた。1人進んだ。",
        "前の人が「もういいです」と言って帰った。1人進んだ。",
        "前の人が荷物をまとめて去っていった。1人進んだ。"
    ]

    static func outcome(totalTaps: Int, seed: Int) -> TapOutcome {
        if QueueEngine.unitRandom(seed, salt: 0xD00F) < departureProbability {
            return TapOutcome(message: pick(departureMessages, seed: seed), didAdvance: true)
        }

        let pool = switch totalTaps {
        case ..<10: firstReactions
        case ..<40: annoyedReactions
        default: coldReactions
        }
        return TapOutcome(message: pick(pool, seed: seed), didAdvance: false)
    }

    private static func pick(_ options: [String], seed: Int) -> String {
        let index = Int(QueueEngine.unitRandom(seed, salt: 0x6B21) * Double(options.count))
        return options[min(index, options.count - 1)]
    }
}
