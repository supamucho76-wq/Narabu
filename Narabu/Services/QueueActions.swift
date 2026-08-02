import Foundation

/// 前の人にできること。相手の様子に合ったものを選べば前に進める。
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
    enum Grade: Equatable {
        /// 相性が良く、大きく進む。
        case great
        /// なんとか通じた。
        case good
        /// 何も起きなかった。
        case miss
        /// 裏目に出て後退した。
        case backfire
    }

    let grade: Grade
    let message: String
    /// 進む人数。後退するときは負になる。
    let advance: Int
    /// 周りの警戒の増減。合わない手を使うと上がる。
    var alertDelta: Double = 0

    /// この行動でコンボが続いたか。
    ///
    /// **アクションでは切れない。** 手が合わなくても前には進むので、
    /// 積み上げが指の運で吹き飛ぶことはない。
    /// 連続が切れるのは、ミッションを落としたときと警備員に捕まったときだけ。
    var keepsCombo: Bool { grade != .backfire }
}

/// 前の人の反応。
enum QueueActions {
    /// 同じアクションを続けたときに落ちる成功率。
    private static let repeatPenalty = 0.22

    /// - Parameters:
    ///   - person: 前に並んでいる人。この人の様子で相性が決まる。
    ///   - repeatCount: 直前に同じアクションを何回続けたか。
    ///   - successBonus: 装備やスキルで上がる成功率。
    ///   - comboBonus: コンボによる追加の前進。
    /// **どの手を選んでも必ず前に進む。**
    ///
    /// 以前は相性の悪い手が後退と連続切れを起こしていた。
    /// 相手の性格は画面に出していないので、それはただの当たり外れでしかなく、
    /// 押すたびに積み上げが吹き飛んで、気持ちよさが立ち上がる前に折れていた。
    ///
    /// いまは合っているかどうかで**進む量**が変わる。
    /// 合わない手の代償は後退ではなく、周りの警戒が上がること。
    /// 警戒を振り切れば警備員に連れ戻され、そこで初めて連続が切れる。
    static func outcome(
        action: QueueAction,
        person: QueuePerson,
        repeatCount: Int,
        seed: Int,
        successBonus: Double = 0,
        comboBonus: Int = 0
    ) -> ActionOutcome {
        let personality = person.personality
        let roll = QueueEngine.unitRandom(seed, salt: 0x51A7)
        // 同じ手を続けると通じにくくなる。止まりはしないが、伸びなくなる。
        let fatigue = min(0.7, Double(repeatCount) * repeatPenalty)
        let bonus = comboBonus + Int((successBonus * 4).rounded())

        if action == personality.worst {
            // 明らかに嫌がられた。それでも列は詰められる。
            return ActionOutcome(
                grade: .good,
                message: personality.failureMessage(for: action),
                advance: max(1, 1 + bonus),
                alertDelta: 0.14
            )
        }

        if action == personality.best {
            // ここが一番大きい。読み切れば伸びる。
            let extra = roll < 0.5 - fatigue * 0.4 ? 2 : 0
            return ActionOutcome(
                grade: .great,
                message: personality.successMessage(for: action),
                advance: max(1, 4 + bonus + extra - Int(fatigue * 3)),
                alertDelta: -0.04
            )
        }

        // 良くも悪くもない相手。それでも確実に詰められる。
        let extra = roll < 0.4 - fatigue * 0.4 ? 1 : 0
        return ActionOutcome(
            grade: .good,
            message: "軽く応じてくれた。前に詰めた。",
            advance: max(1, 2 + bonus + extra - Int(fatigue * 2)),
            alertDelta: 0.02
        )
    }
}
