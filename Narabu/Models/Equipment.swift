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
    let effects: LoadoutEffects
    /// 一覧に出す短い説明。
    let detail: String
}

enum EquipmentCatalog {
    static let all: [Equipment] = [
        Equipment(
            id: "sneakers", name: "ランニングシューズ", slot: .feet,
            symbolName: "shoe.2",
            effects: LoadoutEffects(overtakeMultiplier: 1.2),
            detail: "抜ける人数 +20%"
        ),
        Equipment(
            id: "bicycle", name: "自転車", slot: .feet,
            symbolName: "bicycle",
            effects: LoadoutEffects(overtakeMultiplier: 1.5),
            detail: "抜ける人数 +50%"
        ),
        Equipment(
            id: "motorbike", name: "バイク", slot: .feet,
            symbolName: "figure.outdoor.cycle",
            effects: LoadoutEffects(overtakeMultiplier: 2.0),
            detail: "抜ける人数 +100%"
        ),
        Equipment(
            id: "sunglasses", name: "サングラス", slot: .accessory,
            symbolName: "sunglasses",
            effects: LoadoutEffects(eventSuccessBonus: 0.04),
            detail: "前の人が列を抜ける確率 +4%"
        ),
        Equipment(
            id: "vipPass", name: "VIPパス", slot: .accessory,
            symbolName: "star.circle",
            effects: LoadoutEffects(gachaCooldownMultiplier: 0.7),
            detail: "ガチャの待ち時間 -30%"
        ),
        Equipment(
            id: "ticket", name: "整理券", slot: .pass,
            symbolName: "ticket",
            effects: LoadoutEffects(gachaLuckBonus: 0.15),
            detail: "高レアの出やすさ +15%"
        )
    ]

    static func equipment(id: String) -> Equipment? {
        all.first { $0.id == id }
    }

    static func items(in slot: EquipmentSlot) -> [Equipment] {
        all.filter { $0.slot == slot }
    }
}
