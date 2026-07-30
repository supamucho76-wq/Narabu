import SwiftUI

/// 装備できる部位。ひとつの部位には一度にひとつだけ。
enum EquipmentSlot: String, Codable, CaseIterable, Identifiable, Sendable {
    case feet
    case accessory
    case pass

    var id: String { rawValue }

    var label: String {
        switch self {
        case .feet: "足元"
        case .accessory: "装身具"
        case .pass: "持ち物"
        }
    }
}

/// 身につけると常に効果が出るもの。ガチャのアイテムと違って使っても減らない。
struct Equipment: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let slot: EquipmentSlot
    let symbolName: String
    let rarity: GachaRarity
    let effects: LoadoutEffects
    /// 一覧に出す短い説明。
    let detail: String
    /// どこで手に入るか。まだ持っていない人に見せる。
    let source: String

    /// 「車が100人→200人になる」のように、実際どう変わるかを見せる。
    var concreteExample: String? {
        guard effects.overtakeMultiplier != 1,
              let car = GachaCatalog.item(id: "car") else { return nil }
        let boosted = Int((Double(car.people) * effects.overtakeMultiplier).rounded())
        return "例：\(car.name)が\(car.people)人 → \(boosted)人"
    }
}

enum EquipmentCatalog {
    static let all: [Equipment] = [
        Equipment(
            id: "sneakers", name: "ランニングシューズ", slot: .feet,
            symbolName: "shoe.2", rarity: .n,
            effects: LoadoutEffects(overtakeMultiplier: 1.2),
            detail: "アイテムで抜ける人数が2割増える",
            source: "STAGE 1「コンビニ」クリア"
        ),
        Equipment(
            id: "bicycle", name: "自転車", slot: .feet,
            symbolName: "bicycle", rarity: .r,
            effects: LoadoutEffects(overtakeMultiplier: 1.5),
            detail: "アイテムで抜ける人数が5割増える",
            source: "STAGE 4「テーマパーク」クリア"
        ),
        Equipment(
            id: "motorbike", name: "バイク", slot: .feet,
            symbolName: "figure.outdoor.cycle", rarity: .sr,
            effects: LoadoutEffects(overtakeMultiplier: 2.0),
            detail: "アイテムで抜ける人数が2倍になる",
            source: "STAGE 6「コミケ」クリア"
        ),
        Equipment(
            id: "sunglasses", name: "サングラス", slot: .accessory,
            symbolName: "sunglasses", rarity: .r,
            effects: LoadoutEffects(eventSuccessBonus: 0.04),
            detail: "話しかけたとき、相手が譲ってくれやすくなる",
            source: "STAGE 3「人気カフェ」クリア"
        ),
        Equipment(
            id: "vipPass", name: "VIPパス", slot: .accessory,
            symbolName: "star.circle", rarity: .ssr,
            effects: LoadoutEffects(gachaCooldownMultiplier: 0.7),
            detail: "無料ガチャを待つ時間が3割短くなる",
            source: "STAGE 5「ライブ会場」クリア"
        ),
        Equipment(
            id: "ticket", name: "整理券", slot: .pass,
            symbolName: "ticket", rarity: .sr,
            effects: LoadoutEffects(gachaLuckBonus: 0.15),
            detail: "ガチャで強い乗り物が出やすくなる",
            source: "STAGE 2「人気ラーメン店」クリア"
        )
    ]

    static func equipment(id: String) -> Equipment? {
        all.first { $0.id == id }
    }

    static func items(in slot: EquipmentSlot) -> [Equipment] {
        all.filter { $0.slot == slot }
    }
}
