import Foundation

/// 装備とスキルから集まる、行列の進みかたへの影響。
///
/// 効果はすべてここに集約し、実際の計算はこの値だけを見る。
struct LoadoutEffects: Equatable, Sendable {
    /// アイテムで抜ける人数の倍率。
    var overtakeMultiplier: Double = 1
    /// 無料ガチャの待ち時間の倍率。小さいほど早く引ける。
    var gachaCooldownMultiplier: Double = 1
    /// 前の人に絡んだとき、相手が列を抜ける確率に足す値。
    var eventSuccessBonus: Double = 0
    /// 高レアの出やすさに足す値。
    var gachaLuckBonus: Double = 0

    static let none = LoadoutEffects()

    /// 複数の効果を重ねる。倍率は掛け合わせ、加算値は足す。
    static func combine(_ effects: [LoadoutEffects]) -> LoadoutEffects {
        effects.reduce(into: LoadoutEffects()) { result, effect in
            result.overtakeMultiplier *= effect.overtakeMultiplier
            result.gachaCooldownMultiplier *= effect.gachaCooldownMultiplier
            result.eventSuccessBonus += effect.eventSuccessBonus
            result.gachaLuckBonus += effect.gachaLuckBonus
        }
    }

    /// 効きすぎて壊れないように上限をかける。
    var clamped: LoadoutEffects {
        LoadoutEffects(
            overtakeMultiplier: min(overtakeMultiplier, 8),
            gachaCooldownMultiplier: max(gachaCooldownMultiplier, 0.2),
            eventSuccessBonus: min(eventSuccessBonus, 0.35),
            gachaLuckBonus: min(gachaLuckBonus, 1.0)
        )
    }
}
