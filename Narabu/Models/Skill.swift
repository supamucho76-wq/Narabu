import Foundation

/// 育てると列の進みかたが良くなるもの。ステージクリアで覚え、コインで伸ばす。
struct Skill: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let symbolName: String
    let detail: String
    /// 1段階あたりの効果。段階の数だけ重ねて効く。
    let perLevel: LoadoutEffects

    static let maxLevel = 5

    /// 次の段階に上げるのに必要なコイン。上げるほど高くなる。
    static func upgradeCost(currentLevel: Int) -> Int {
        200 * Int(pow(2.0, Double(currentLevel - 1)))
    }

    func effects(atLevel level: Int) -> LoadoutEffects {
        LoadoutEffects.combine(Array(repeating: perLevel, count: max(0, level)))
    }
}

enum SkillCatalog {
    static let all: [Skill] = [
        Skill(
            id: "talk", name: "話術",
            symbolName: "bubble.left.and.bubble.right",
            detail: "前の人が列を抜ける確率が上がる",
            perLevel: LoadoutEffects(eventSuccessBonus: 0.02)
        ),
        Skill(
            id: "pressure", name: "威圧",
            symbolName: "flame",
            detail: "アイテムで抜ける人数が増える",
            perLevel: LoadoutEffects(overtakeMultiplier: 1.1)
        ),
        Skill(
            id: "luck", name: "運",
            symbolName: "clover",
            detail: "高レアのアイテムが出やすくなる",
            perLevel: LoadoutEffects(gachaLuckBonus: 0.06)
        ),
        Skill(
            id: "negotiate", name: "交渉術",
            symbolName: "handshake",
            detail: "無料ガチャの待ち時間が短くなる",
            perLevel: LoadoutEffects(gachaCooldownMultiplier: 0.93)
        )
    ]

    static func skill(id: String) -> Skill? {
        all.first { $0.id == id }
    }
}
