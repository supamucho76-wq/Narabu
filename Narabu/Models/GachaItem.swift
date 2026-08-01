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
enum VehicleKind: String, Codable, CaseIterable, Sendable {
    case running
    case hopping
    case bicycle
    case scooter
    case cart
    case motorbike
    case gang
    case palanquin
    case animal
    case dinosaur
    case car
    case fireTruck
    case helicopter
    case train
    case ufo
    case rocket
    case divineHand
}

enum GachaCatalog {
    /// 排出されるアイテムの全種類。ここの数値を変えれば全体に反映される。
    ///
    /// 等級ごとに4つずつ。同じ等級の中でも抜ける人数に差をつけて、
    /// 引くたびに当たり外れが出るようにしている。
    static let items: [GachaItem] = [
        // N（合計35%）
        GachaItem(
            id: "hop", name: "ケンケン", rarity: .n,
            people: 3, dropRate: 0.0875, overtakeDuration: 1.0,
            symbolName: "figure.stand", vehicle: .hopping
        ),
        GachaItem(
            id: "dash", name: "ダッシュ", rarity: .n,
            people: 5, dropRate: 0.0875, overtakeDuration: 1.0,
            symbolName: "figure.run", vehicle: .running
        ),
        GachaItem(
            id: "tricycle", name: "三輪車", rarity: .n,
            people: 7, dropRate: 0.0875, overtakeDuration: 1.2,
            symbolName: "bicycle", vehicle: .bicycle
        ),
        GachaItem(
            id: "sprint", name: "全力疾走", rarity: .n,
            people: 9, dropRate: 0.0875, overtakeDuration: 1.2,
            symbolName: "figure.run.circle", vehicle: .running
        ),

        // R（合計30%）
        GachaItem(
            id: "cart", name: "台車", rarity: .r,
            people: 13, dropRate: 0.075, overtakeDuration: 1.4,
            symbolName: "cart.fill", vehicle: .cart
        ),
        GachaItem(
            id: "kickboard", name: "キックボード", rarity: .r,
            people: 17, dropRate: 0.075, overtakeDuration: 1.5,
            symbolName: "scooter", vehicle: .scooter
        ),
        GachaItem(
            id: "bicycle", name: "自転車", rarity: .r,
            people: 20, dropRate: 0.075, overtakeDuration: 1.5,
            symbolName: "bicycle", vehicle: .bicycle
        ),
        GachaItem(
            id: "deliveryBike", name: "出前の原付", rarity: .r,
            people: 26, dropRate: 0.075, overtakeDuration: 1.7,
            symbolName: "takeoutbag.and.cup.and.straw.fill", vehicle: .motorbike
        ),

        // SR（合計20%）
        GachaItem(
            id: "palanquin", name: "神輿", rarity: .sr,
            people: 38, dropRate: 0.05, overtakeDuration: 2.0,
            symbolName: "figure.socialdance", vehicle: .palanquin
        ),
        GachaItem(
            id: "motorbike", name: "バイク", rarity: .sr,
            people: 50, dropRate: 0.05, overtakeDuration: 2.0,
            symbolName: "figure.outdoor.cycle", vehicle: .motorbike
        ),
        GachaItem(
            id: "ostrich", name: "ダチョウ", rarity: .sr,
            people: 62, dropRate: 0.05, overtakeDuration: 2.1,
            symbolName: "bird.fill", vehicle: .animal
        ),
        GachaItem(
            id: "gang", name: "暴走族の集団", rarity: .sr,
            people: 75, dropRate: 0.05, overtakeDuration: 2.3,
            symbolName: "flame.fill", vehicle: .gang
        ),

        // SSR（合計12%）
        GachaItem(
            id: "car", name: "車", rarity: .ssr,
            people: 100, dropRate: 0.03, overtakeDuration: 2.4,
            symbolName: "car.fill", vehicle: .car
        ),
        GachaItem(
            id: "fireTruck", name: "消防車", rarity: .ssr,
            people: 125, dropRate: 0.03, overtakeDuration: 2.5,
            symbolName: "car.rear.waves.up.fill", vehicle: .fireTruck
        ),
        GachaItem(
            id: "trex", name: "ティラノサウルス", rarity: .ssr,
            people: 160, dropRate: 0.03, overtakeDuration: 2.7,
            symbolName: "lizard.fill", vehicle: .dinosaur
        ),
        GachaItem(
            id: "helicopter", name: "ヘリコプター", rarity: .ssr,
            people: 200, dropRate: 0.03, overtakeDuration: 2.8,
            symbolName: "helicopter", vehicle: .helicopter
        ),

        // UR（合計3%）
        GachaItem(
            id: "train", name: "電車", rarity: .ur,
            people: 300, dropRate: 0.0075, overtakeDuration: 3.0,
            symbolName: "tram.fill", vehicle: .train
        ),
        GachaItem(
            id: "rocket", name: "ロケット", rarity: .ur,
            people: 450, dropRate: 0.0075, overtakeDuration: 3.2,
            symbolName: "airplane.departure", vehicle: .rocket
        ),
        GachaItem(
            id: "ufo", name: "UFO", rarity: .ur,
            people: 600, dropRate: 0.0075, overtakeDuration: 3.4,
            symbolName: "circle.dotted", vehicle: .ufo
        ),
        GachaItem(
            id: "divineHand", name: "神様の手", rarity: .ur,
            people: 999, dropRate: 0.0075, overtakeDuration: 3.6,
            symbolName: "hand.raised.fill", vehicle: .divineHand
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
