import Foundation

/// 声で押し通した結果。
struct BreakthroughOutcome: Equatable {
    let phrase: VoicePhrase
    let volume: VoiceVolume
    let succeeded: Bool
    /// 進む人数。失敗して下がるときは負。
    let advance: Int
    /// 上がった警戒度。丁寧な言葉なら負になる。
    let alertDelta: Double
    let message: String
    /// 警備員に見つかったか。
    let caughtByGuard: Bool
}

/// 声とタップ、どちらの操作でも同じ計算で結果を出す。
///
/// 声を出せない場所でも不利にならないよう、強さの決まりかたを共通にしてある。
enum BreakthroughResolver {
    static func resolve(
        phrase: VoicePhrase,
        volume: VoiceVolume,
        person: QueuePerson,
        alertness: Double,
        repeatCount: Int,
        remaining: Int,
        seed: Int
    ) -> BreakthroughOutcome {
        let level = Alertness.level(alertness)
        let roll = QueueEngine.unitRandom(seed, salt: 0x71C3)

        var chance = phrase.baseChance

        // 言葉に合った声の大きさなら通りやすい。
        if volume == phrase.preferredVolume { chance += 0.12 }
        // 叫ぶと目立つだけで、あまり通らない。
        if volume == .tooLoud { chance -= 0.1 }
        // 乱暴な手は、警戒されているほど効かなくなる。
        if phrase.isRough { chance -= level.roughPenalty }
        // 怒っている人に強く出ると逆効果。
        if phrase.isRough, person.personality == .grumpy { chance -= 0.25 }
        // 急いでいる人には、急ぐ理由が通じやすい。
        if phrase == .isoide, person.personality == .hurried { chance += 0.2 }
        // 親切な人は頼めば応じてくれる。
        if phrase == .onegai, person.personality == .kind { chance += 0.2 }
        // 同じ言葉ばかりだと飽きられる。
        chance -= min(0.5, Double(repeatCount) * 0.18)

        var alertDelta = phrase.alertCost
        if volume == .tooLoud { alertDelta += 12 }

        // 叫び続けると、警備員に見つかる。
        let guardRoll = QueueEngine.unitRandom(seed, salt: 0x82D4)
        let caught = guardRoll < Alertness.guardChance(alertness + max(0, alertDelta))

        if caught {
            return BreakthroughOutcome(
                phrase: phrase,
                volume: volume,
                succeeded: false,
                advance: -min(remaining > 0 ? 8 : 0, 8),
                alertDelta: -40,
                message: "警備員に肩を掴まれた。後ろまで戻された。",
                caughtByGuard: true
            )
        }

        guard roll < max(0.08, chance) else {
            let cost = phrase.failureCostsGround ? -1 : 0
            return BreakthroughOutcome(
                phrase: phrase,
                volume: volume,
                succeeded: false,
                advance: cost,
                alertDelta: alertDelta,
                message: failureMessage(phrase: phrase, person: person),
                caughtByGuard: false
            )
        }

        // 通ったときの人数。声が合っているほど上振れする。
        let range = phrase.advanceRange
        let width = Double(range.upperBound - range.lowerBound)
        let bonus = volume == phrase.preferredVolume ? 0.35 : 0
        let position = min(1, QueueEngine.unitRandom(seed, salt: 0x93E5) + bonus)
        let advance = range.lowerBound + Int(width * position)

        return BreakthroughOutcome(
            phrase: phrase,
            volume: volume,
            succeeded: true,
            advance: min(advance, max(0, remaining)),
            alertDelta: alertDelta,
            message: successMessage(phrase: phrase, advance: advance),
            caughtByGuard: false
        )
    }

    private static func successMessage(phrase: VoicePhrase, advance: Int) -> String {
        switch phrase {
        case .oi: "前の人たちが驚いて振り返った。道が空いた。"
        case .doke: "気圧されて、まとめて脇に避けた。"
        case .jama: "露骨に嫌な顔をされたが、通してはくれた。"
        case .tooshite: "「どうぞ」と体をひねって通してくれた。"
        case .isoide: "事情を察して、順番を譲ってくれた。"
        case .sumimasen: "丁寧に頼んだら、すんなり通してくれた。"
        case .onegai: "何人かが顔を見合わせて、場所を空けてくれた。"
        case .maeni: "「しょうがないなあ」と前に入れてくれた。"
        }
    }

    private static func failureMessage(phrase: VoicePhrase, person: QueuePerson) -> String {
        if phrase.isRough, person.personality == .grumpy {
            return "怒鳴り返された。完全に敵に回した。"
        }
        return switch phrase {
        case .oi, .doke, .jama: "誰も動かない。数人がこちらを睨んでいる。"
        case .isoide: "「みんな急いでますよ」と返された。"
        case .sumimasen, .onegai: "気づいてもらえなかった。"
        default: "反応がない。声が通らなかったようだ。"
        }
    }
}
