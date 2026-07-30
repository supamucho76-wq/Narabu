import Foundation

/// 何週間も並んだ末に受け取れる景品。値打ちは一切ない。
struct Prize: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    /// 受け取り窓口で読み上げられる、事務的な一言。
    let note: String
    let rarity: PrizeRarity
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
}
