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
    /// この行動でコンボが続いたか。
    var keepsCombo: Bool { grade == .great || grade == .good }
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
        let fatigue = min(0.7, Double(repeatCount) * repeatPenalty)

        // やってはいけない相手にやると、確実に裏目に出る。
        if action == personality.worst {
            return ActionOutcome(
                grade: .backfire,
                message: personality.failureMessage(for: action),
                advance: -1
            )
        }

        if action == personality.best {
            let chance = 0.92 + successBonus - fatigue
            if roll < chance {
                return ActionOutcome(
                    grade: .great,
                    message: personality.successMessage(for: action),
                    advance: 2 + comboBonus + (roll < chance * 0.4 ? 1 : 0)
                )
            }
            return ActionOutcome(
                grade: .miss,
                message: "同じ手ばかりで、飽きられてしまった。",
                advance: 0
            )
        }

        // 相性が良くも悪くもない相手。半々で少し進む。
        let chance = 0.45 + successBonus - fatigue
        if roll < chance {
            return ActionOutcome(
                grade: .good,
                message: "軽く応じてくれた。少しだけ前に詰めた。",
                advance: 1 + comboBonus
            )
        }
        return ActionOutcome(
            grade: .miss,
            message: personality.failureMessage(for: action),
            advance: 0
        )
    }
}
