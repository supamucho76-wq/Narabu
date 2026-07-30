import SwiftUI

/// ガチャの等級。演出の派手さもここで決まる。
enum GachaRarity: String, Codable, CaseIterable, Sendable {
    case n
    case r
    case sr
    case ssr
    case ur

    var label: String {
        switch self {
        case .n: "N"
        case .r: "R"
        case .sr: "SR"
        case .ssr: "SSR"
        case .ur: "UR"
        }
    }

    var color: Color {
        switch self {
        case .n: Color(red: 0.58, green: 0.60, blue: 0.64)
        case .r: Color(red: 0.36, green: 0.62, blue: 0.86)
        case .sr: Color(red: 0.70, green: 0.44, blue: 0.88)
        case .ssr: Color(red: 0.96, green: 0.72, blue: 0.24)
        case .ur: Color(red: 0.98, green: 0.36, blue: 0.52)
        }
    }

    /// 光の強さ。0 が簡素、1 が最大。
    var glowStrength: Double {
        switch self {
        case .n: 0.0
        case .r: 0.28
        case .sr: 0.55
        case .ssr: 0.8
        case .ur: 1.0
        }
    }

    /// 虹色の特別演出をするか。
    var isRainbow: Bool { self == .ur }

    /// 引くときのためが長いほど、期待が高まる。
    var buildUpDuration: Double {
        switch self {
        case .n: 0.5
        case .r: 0.7
        case .sr: 0.9
        case .ssr: 1.2
        case .ur: 1.7
        }
    }
}

/// ガチャから出るごぼう抜きアイテム。
///
/// 追い抜き人数・排出率・演出時間はここだけで管理する。UI側には数値を書かない。
struct GachaItem: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let rarity: GachaRarity
    /// 追い抜ける人数。
    let people: Int
    /// 排出率。全アイテムの合計が 1.0 になる。
    let dropRate: Double
    /// ごぼう抜き演出の長さ（秒）。
    let overtakeDuration: Double
    /// 差し替えやすいように、画像ではなくシンボル名で持つ。
    let symbolName: String
    /// 乗り物の描きかた。
    let vehicle: VehicleKind

    var summary: String { "\(people)人抜き" }
}

/// 乗り物の見た目。
enum VehicleKind: String, Codable, Sendable {
    case running
    case bicycle
    case motorbike
    case car
    case train
}

enum GachaCatalog {
    /// 排出されるアイテムの全種類。ここの数値を変えれば全体に反映される。
    static let items: [GachaItem] = [
        GachaItem(
            id: "dash", name: "ダッシュ", rarity: .n,
            people: 5, dropRate: 0.35, overtakeDuration: 1.0,
            symbolName: "figure.run", vehicle: .running
        ),
        GachaItem(
            id: "bicycle", name: "自転車", rarity: .r,
            people: 20, dropRate: 0.30, overtakeDuration: 1.5,
            symbolName: "bicycle", vehicle: .bicycle
        ),
        GachaItem(
            id: "motorbike", name: "バイク", rarity: .sr,
            people: 50, dropRate: 0.20, overtakeDuration: 2.0,
            symbolName: "figure.outdoor.cycle", vehicle: .motorbike
        ),
        GachaItem(
            id: "car", name: "車", rarity: .ssr,
            people: 100, dropRate: 0.12, overtakeDuration: 2.5,
            symbolName: "car.fill", vehicle: .car
        ),
        GachaItem(
            id: "train", name: "電車", rarity: .ur,
            people: 300, dropRate: 0.03, overtakeDuration: 3.0,
            symbolName: "tram.fill", vehicle: .train
        )
    ]

    /// 初回に無料で引ける回数。
    static let starterDrawCount = 5
    /// 無料ガチャの間隔。
    static let freeGachaInterval: TimeInterval = 3_600

    static func item(id: String) -> GachaItem? {
        items.first { $0.id == id }
    }
}
