import SwiftUI

/// 列が通っている場所。ステージごとに、あるいはステージの中で移り変わる。
enum SceneKind: String, Codable, CaseIterable, Sendable {
    case residential
    case shopping
    case forest
    case park
    case night
    case hall
    case sea
    case snow
    case desert
    case space
    case hell
    case heaven
    case ramen

    var name: String {
        switch self {
        case .residential: "住宅街"
        case .shopping: "商店街"
        case .forest: "並木道"
        case .park: "遊園地"
        case .night: "夜の会場前"
        case .hall: "巨大会場"
        case .sea: "海の上"
        case .snow: "雪国"
        case .desert: "砂漠"
        case .space: "宇宙"
        case .hell: "地獄"
        case .heaven: "天国"
        case .ramen: "店の前"
        }
    }

    /// 空の色。上と地平線ぎわの2色。
    var skyColors: (top: Color, bottom: Color) {
        switch self {
        case .residential:
            (Color(red: 0.52, green: 0.72, blue: 0.90), Color(red: 0.88, green: 0.90, blue: 0.88))
        case .shopping:
            (Color(red: 0.66, green: 0.70, blue: 0.84), Color(red: 0.97, green: 0.86, blue: 0.68))
        case .forest:
            (Color(red: 0.48, green: 0.70, blue: 0.74), Color(red: 0.86, green: 0.90, blue: 0.78))
        case .park:
            (Color(red: 0.44, green: 0.68, blue: 0.92), Color(red: 0.98, green: 0.86, blue: 0.90))
        case .night:
            (Color(red: 0.08, green: 0.07, blue: 0.18), Color(red: 0.36, green: 0.18, blue: 0.42))
        case .hall:
            (Color(red: 0.58, green: 0.66, blue: 0.78), Color(red: 0.86, green: 0.86, blue: 0.88))
        case .sea:
            (Color(red: 0.28, green: 0.60, blue: 0.84), Color(red: 0.76, green: 0.90, blue: 0.94))
        case .snow:
            (Color(red: 0.52, green: 0.60, blue: 0.74), Color(red: 0.92, green: 0.94, blue: 0.97))
        case .desert:
            (Color(red: 0.44, green: 0.62, blue: 0.86), Color(red: 0.98, green: 0.84, blue: 0.58))
        case .space:
            (Color(red: 0.03, green: 0.02, blue: 0.10), Color(red: 0.16, green: 0.10, blue: 0.30))
        case .hell:
            (Color(red: 0.22, green: 0.03, blue: 0.04), Color(red: 0.74, green: 0.22, blue: 0.08))
        case .heaven:
            (Color(red: 0.72, green: 0.86, blue: 0.98), Color(red: 1.0, green: 0.97, blue: 0.86))
        case .ramen:
            (Color(red: 0.16, green: 0.12, blue: 0.12), Color(red: 0.44, green: 0.20, blue: 0.14))
        }
    }

    /// 道の色。
    var groundColor: Color {
        switch self {
        case .residential: Color(red: 0.60, green: 0.59, blue: 0.57)
        case .shopping: Color(red: 0.54, green: 0.51, blue: 0.50)
        case .forest: Color(red: 0.42, green: 0.40, blue: 0.30)
        case .park: Color(red: 0.66, green: 0.60, blue: 0.56)
        case .night: Color(red: 0.22, green: 0.20, blue: 0.28)
        case .hall: Color(red: 0.52, green: 0.52, blue: 0.54)
        case .sea: Color(red: 0.30, green: 0.52, blue: 0.66)
        case .snow: Color(red: 0.88, green: 0.90, blue: 0.93)
        case .desert: Color(red: 0.86, green: 0.72, blue: 0.46)
        case .space: Color(red: 0.20, green: 0.18, blue: 0.30)
        case .hell: Color(red: 0.32, green: 0.14, blue: 0.10)
        case .heaven: Color(red: 0.92, green: 0.92, blue: 0.96)
        case .ramen: Color(red: 0.34, green: 0.26, blue: 0.22)
        }
    }

    /// 道の両脇に立っているものの色。
    var propColor: Color {
        switch self {
        case .residential: Color(red: 0.80, green: 0.76, blue: 0.70)
        case .shopping: Color(red: 0.72, green: 0.44, blue: 0.36)
        case .forest: Color(red: 0.20, green: 0.40, blue: 0.26)
        case .park: Color(red: 0.92, green: 0.42, blue: 0.46)
        case .night: Color(red: 0.34, green: 0.24, blue: 0.48)
        case .hall: Color(red: 0.66, green: 0.66, blue: 0.70)
        case .sea: Color(red: 0.90, green: 0.88, blue: 0.84)
        case .snow: Color(red: 0.72, green: 0.78, blue: 0.84)
        case .desert: Color(red: 0.52, green: 0.70, blue: 0.42)
        case .space: Color(red: 0.52, green: 0.46, blue: 0.72)
        case .hell: Color(red: 0.14, green: 0.08, blue: 0.08)
        case .heaven: Color(red: 0.98, green: 0.94, blue: 0.78)
        case .ramen: Color(red: 0.68, green: 0.20, blue: 0.16)
        }
    }
}
