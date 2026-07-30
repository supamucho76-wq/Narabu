import SwiftUI

/// 並んだ末に受け取れる記念品。値打ちは一切ない。
struct Prize: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    /// 受け取り窓口で読み上げられる、事務的な一言。
    let note: String
    let rarity: PrizeRarity
    /// ごく一部の景品だけが持っている、説明のつかない効果。
    let hiddenEffect: LoadoutEffects?

    init(
        id: String,
        name: String,
        note: String,
        rarity: PrizeRarity,
        hiddenEffect: LoadoutEffects? = nil
    ) {
        self.id = id
        self.name = name
        self.note = note
        self.rarity = rarity
        self.hiddenEffect = hiddenEffect
    }

    /// 隠し効果の説明。持っていることに気づくと少し嬉しい。
    var hiddenEffectLabel: String? {
        guard let hiddenEffect else { return nil }
        if hiddenEffect.gachaLuckBonus != 0 {
            return "なぜか高レアが出やすくなる（+\(hiddenEffect.gachaLuckBonus.formatted(.percent.precision(.fractionLength(0)))))"
        }
        if hiddenEffect.eventSuccessBonus != 0 {
            return "なぜか譲ってもらえやすくなる（+\(hiddenEffect.eventSuccessBonus.formatted(.percent.precision(.fractionLength(0)))))"
        }
        if hiddenEffect.overtakeMultiplier != 1 {
            return "なぜか少しだけ多く抜ける（×\(hiddenEffect.overtakeMultiplier.formatted(.number.precision(.fractionLength(0...2)))))"
        }
        if hiddenEffect.gachaCooldownMultiplier != 1 {
            return "なぜかガチャが少し早く引ける"
        }
        return nil
    }
}

/// 値打ちのないものにも序列はある。
enum PrizeRarity: String, Codable, CaseIterable, Sendable {
    case ordinary
    case odd
    case inexplicable

    var label: String {
        switch self {
        case .ordinary: "ふつう"
        case .odd: "ちょっと変"
        case .inexplicable: "なぜか貴重"
        }
    }

    /// 図鑑で枠の色を変えるのに使う。
    var color: Color {
        switch self {
        case .ordinary: Color(red: 0.55, green: 0.56, blue: 0.58)
        case .odd: Color(red: 0.42, green: 0.60, blue: 0.80)
        case .inexplicable: Color(red: 0.82, green: 0.58, blue: 0.22)
        }
    }
}
