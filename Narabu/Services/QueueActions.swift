import Foundation

/// 前の人にできること。どれをやっても列は進まない。
enum QueueAction: String, CaseIterable, Identifiable, Sendable {
    case tapShoulder
    case talk
    case surprise
    case cheer
    case highFive

    var id: String { rawValue }

    var label: String {
        switch self {
        case .tapShoulder: "肩を叩く"
        case .talk: "話しかける"
        case .surprise: "驚かせる"
        case .cheer: "応援する"
        case .highFive: "ハイタッチ"
        }
    }

    var symbolName: String {
        switch self {
        case .tapShoulder: "hand.tap"
        case .talk: "bubble.left"
        case .surprise: "exclamationmark.bubble"
        case .cheer: "hands.clap"
        case .highFive: "hand.raised"
        }
    }
}

/// アクションの結果。
struct ActionOutcome: Equatable {
    let message: String
    /// 前の人が列を抜けて、1人ぶん進んだかどうか。
    let didAdvance: Bool
}

/// 前の人の反応。絡んだ回数が増えるほど、相手の態度が冷たくなっていく。
enum QueueActions {
    /// 絡まれた人が列を抜けてしまう確率。
    private static let departureProbability = 0.02

    private static let reactions: [QueueAction: [String]] = [
        .tapShoulder: [
            "前の人が振り返った。",
            "前の人が肩を払った。",
            "前の人が「はい？」と言った。",
            "前の人が驚いて少し前に詰めた。",
            "前の人が会釈だけして前を向いた。"
        ],
        .talk: [
            "前の人が天気の話をしてくれた。",
            "前の人が「まだ先は長いですね」と言った。",
            "前の人がイヤホンを外して聞き返した。",
            "前の人が何か言ったが、よく聞こえなかった。",
            "前の人が自分の並んだ日数を教えてくれた。",
            "前の人が列の先に何があるか知らないと言った。"
        ],
        .surprise: [
            "前の人が飛び上がった。",
            "前の人が持っていたものを落としかけた。",
            "前の人が全く動じなかった。",
            "前の人がゆっくり振り返って、じっと見てきた。",
            "前の人が笑った。"
        ],
        .cheer: [
            "前の人が親指を立てた。",
            "前の人が照れている。",
            "前の人が「お互い頑張りましょう」と言った。",
            "前の人が背筋を伸ばした。",
            "前の人が振り返らずに手だけ振った。"
        ],
        .highFive: [
            "ハイタッチが決まった。いい音がした。",
            "前の人が手を出すのが遅れて、空振りした。",
            "前の人が両手で応じてきた。",
            "前の人が握手だと思って握ってきた。",
            "前の人が一瞬迷ってから応じてくれた。"
        ]
    ]

    private static let coldReactions = [
        "前の人はもう振り返らない。",
        "前の人があなたを覚えたようだ。",
        "前の人が黙って前を見ている。",
        "前の人が後ろの人に何か言った。",
        "前の人が半歩だけ距離を取った。"
    ]

    private static let departureMessages = [
        "前の人が列を抜けた。1人進んだ。",
        "前の人が「もういいです」と言って帰った。1人進んだ。",
        "前の人が荷物をまとめて去っていった。1人進んだ。",
        "前の人が受付を諦めた。1人進んだ。"
    ]

    /// - Parameter successBonus: 装備やスキルで上がる、相手が列を抜ける確率。
    static func outcome(
        action: QueueAction,
        totalInteractions: Int,
        seed: Int,
        successBonus: Double = 0
    ) -> ActionOutcome {
        if QueueEngine.unitRandom(seed, salt: 0xD00F) < departureProbability + successBonus {
            return ActionOutcome(message: pick(departureMessages, seed: seed), didAdvance: true)
        }

        // 絡みすぎると、何をしても相手にされなくなる。
        if totalInteractions > 60, QueueEngine.unitRandom(seed, salt: 0xE11A) < 0.5 {
            return ActionOutcome(message: pick(coldReactions, seed: seed), didAdvance: false)
        }

        let pool = reactions[action] ?? coldReactions
        return ActionOutcome(message: pick(pool, seed: seed), didAdvance: false)
    }

    private static func pick(_ options: [String], seed: Int) -> String {
        let index = Int(QueueEngine.unitRandom(seed, salt: 0x6B21) * Double(options.count))
        return options[min(index, options.count - 1)]
    }
}
