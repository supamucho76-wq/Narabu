import SwiftUI

/// 連続成功の段。
///
/// **爽快感はここで作る。** 1回の前進を大きくするのではなく、
/// 続けたぶんだけ跳ね上がるようにして、腕で数字を伸ばせるようにする。
/// 1000人の行列を19人ずつ削るのは作業だが、
/// 続ければ150人が一度に消えるなら、続ける理由になる。
///
/// 倍率がかかるのは**自力で進んだぶんだけ**。
/// ガチャの乗り物は元から大きいので、ここには乗せない。
enum ComboTier: Int, CaseIterable, Comparable, Sendable {
    case none
    case warm
    case hot
    case fever
    case blaze
    case rampage

    /// この段に入るのに要る連続回数。
    var requiredCombo: Int {
        switch self {
        case .none: 0
        case .warm: 3
        case .hot: 5
        case .fever: 8
        case .blaze: 12
        case .rampage: 16
        }
    }

    static func of(_ combo: Int) -> ComboTier {
        // 上から見て、届いている一番高い段を返す。
        allCases.reversed().first { combo >= $0.requiredCombo } ?? .none
    }

    /// 自力で進んだ人数にかける倍率。
    var multiplier: Double {
        switch self {
        case .none: 1
        case .warm: 1.5
        case .hot: 2
        case .fever: 3
        case .blaze: 5
        case .rampage: 8
        }
    }

    /// 画面に出す名前。最初の段だけは何も出さない。
    var label: String? {
        switch self {
        case .none: nil
        case .warm: "ノッてきた"
        case .hot: "加速"
        case .fever: "フィーバー"
        case .blaze: "爆走"
        case .rampage: "暴走"
        }
    }

    var color: Color {
        switch self {
        case .none: .white
        case .warm: Color(red: 0.98, green: 0.92, blue: 0.60)
        case .hot: Color(red: 1.00, green: 0.78, blue: 0.24)
        case .fever: Color(red: 1.00, green: 0.58, blue: 0.16)
        case .blaze: Color(red: 1.00, green: 0.34, blue: 0.26)
        case .rampage: Color(red: 1.00, green: 0.26, blue: 0.56)
        }
    }

    var symbolName: String {
        switch self {
        case .none, .warm: "bolt.fill"
        case .hot, .fever: "flame.fill"
        case .blaze, .rampage: "burst.fill"
        }
    }

    /// 倍率の表示。1倍のときは出さない。
    var multiplierLabel: String? {
        guard multiplier > 1 else { return nil }
        // 1.5倍だけ小数が要る。
        return multiplier == 1.5 ? "×1.5" : "×\(Int(multiplier))"
    }

    var next: ComboTier? { ComboTier(rawValue: rawValue + 1) }

    static func < (lhs: ComboTier, rhs: ComboTier) -> Bool { lhs.rawValue < rhs.rawValue }
}
