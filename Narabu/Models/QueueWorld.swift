import SwiftUI

/// 列が通り抜けていく場所。
///
/// 並んでいる先はただのラーメン屋だが、列が長すぎて森も海も宇宙も地獄も通る。
enum SceneKind: String, Codable, CaseIterable, Sendable {
    case residential
    case shopping
    case forest
    case sea
    case snow
    case desert
    case space
    case hell
    case heaven
    case ramen
}

/// 進捗の区間ごとの景色。
struct WorldStage: Equatable, Sendable {
    /// この場所が終わる進捗。
    let untilProgress: Int
    let name: String
    /// 場所に着いたときに出る一言。
    let arrivalNote: String
    let kind: SceneKind
}

/// 8000人の列と、その道のり。
enum QueueWorld {
    /// 並んでいる先。
    static let destination = "世界一号店 ラーメン"

    /// 列に並んでいる人数。
    static let length = 8_000

    static let stages: [WorldStage] = [
        WorldStage(untilProgress: 1_000, name: "住宅街",
                   arrivalNote: "店はこの先らしい。", kind: .residential),
        WorldStage(untilProgress: 2_000, name: "商店街",
                   arrivalNote: "シャッターに「最後尾」の貼り紙がある。", kind: .shopping),
        WorldStage(untilProgress: 3_000, name: "森",
                   arrivalNote: "列は森に入った。まだ店は見えない。", kind: .forest),
        WorldStage(untilProgress: 4_000, name: "海",
                   arrivalNote: "列が海の上に続いている。誰も気にしていない。", kind: .sea),
        WorldStage(untilProgress: 5_000, name: "雪国",
                   arrivalNote: "気づけば雪国。ラーメンが恋しくなってきた。", kind: .snow),
        WorldStage(untilProgress: 6_000, name: "砂漠",
                   arrivalNote: "砂漠。スープの塩分が心配になる。", kind: .desert),
        WorldStage(untilProgress: 7_000, name: "宇宙",
                   arrivalNote: "宇宙。ラーメン屋の行列である。", kind: .space),
        WorldStage(untilProgress: 7_600, name: "地獄",
                   arrivalNote: "地獄。並んでいる人の顔ぶれは特に変わらない。", kind: .hell),
        WorldStage(untilProgress: 8_000, name: "天国",
                   arrivalNote: "天国。店はもうすぐらしい。", kind: .heaven),
        WorldStage(untilProgress: .max, name: "世界一号店",
                   arrivalNote: "着いた。暖簾が出ている。", kind: .ramen)
    ]

    static func stage(at progress: Int) -> WorldStage {
        stages.first { progress < $0.untilProgress } ?? stages[stages.count - 1]
    }

    static func stageIndex(at progress: Int) -> Int {
        stages.firstIndex { progress < $0.untilProgress } ?? stages.count - 1
    }

    /// 今の場所に入ってからの進み具合。景色を繋ぐときの混ぜ具合に使う。
    static func entryBlend(at progress: Int, over people: Int = 250) -> Double {
        let index = stageIndex(at: progress)
        guard index > 0 else { return 1 }
        let entered = progress - stages[index - 1].untilProgress
        return min(1, max(0, Double(entered) / Double(people)))
    }

    /// 次の景色に変わるまでの残り人数。
    static func peopleUntilNextStage(at progress: Int) -> Int? {
        let stage = stage(at: progress)
        guard stage.untilProgress != .max else { return nil }
        return stage.untilProgress - progress
    }
}

extension SceneKind {
    /// 空の色。上と地平線ぎわの2色。
    var skyColors: (top: Color, bottom: Color) {
        switch self {
        case .residential:
            (Color(red: 0.52, green: 0.72, blue: 0.90), Color(red: 0.88, green: 0.90, blue: 0.88))
        case .shopping:
            (Color(red: 0.66, green: 0.70, blue: 0.84), Color(red: 0.97, green: 0.86, blue: 0.68))
        case .forest:
            (Color(red: 0.48, green: 0.70, blue: 0.74), Color(red: 0.86, green: 0.90, blue: 0.78))
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
