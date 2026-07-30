import SwiftUI

/// 列が通り抜けていく場所。進むにつれて景色が変わっていく。
enum SceneKind: String, Codable, CaseIterable, Sendable {
    case residential
    case shopping
    case forest
    case snow
    case hotel
    case palace
    case reception
}

/// 進捗の区間ごとの景色。
struct WorldStage: Equatable, Sendable {
    /// この場所が終わる進捗。
    let untilProgress: Int
    let name: String
    let kind: SceneKind
}

/// 8000人の列と、その道のり。
enum QueueWorld {
    /// 列に並んでいる人数。この人数ぶん進むと受付にたどり着く。
    static let length = 8_000

    static let stages: [WorldStage] = [
        WorldStage(untilProgress: 1_000, name: "住宅街", kind: .residential),
        WorldStage(untilProgress: 3_000, name: "商店街", kind: .shopping),
        WorldStage(untilProgress: 5_000, name: "森林", kind: .forest),
        WorldStage(untilProgress: 7_000, name: "雪景色", kind: .snow),
        WorldStage(untilProgress: 7_900, name: "高級ホテル街", kind: .hotel),
        WorldStage(untilProgress: 8_000, name: "豪華な建物", kind: .palace),
        WorldStage(untilProgress: .max, name: "受付", kind: .reception)
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
    /// 空の色。奥に向かって薄くなる上下2色。
    var skyColors: (top: Color, bottom: Color) {
        switch self {
        case .residential:
            (Color(red: 0.62, green: 0.76, blue: 0.88), Color(red: 0.88, green: 0.90, blue: 0.88))
        case .shopping:
            (Color(red: 0.72, green: 0.74, blue: 0.82), Color(red: 0.95, green: 0.89, blue: 0.78))
        case .forest:
            (Color(red: 0.55, green: 0.72, blue: 0.76), Color(red: 0.85, green: 0.89, blue: 0.80))
        case .snow:
            (Color(red: 0.58, green: 0.64, blue: 0.74), Color(red: 0.90, green: 0.92, blue: 0.95))
        case .hotel:
            (Color(red: 0.28, green: 0.34, blue: 0.50), Color(red: 0.78, green: 0.72, blue: 0.72))
        case .palace:
            (Color(red: 0.20, green: 0.22, blue: 0.36), Color(red: 0.72, green: 0.62, blue: 0.52))
        case .reception:
            (Color(red: 0.16, green: 0.16, blue: 0.20), Color(red: 0.34, green: 0.30, blue: 0.30))
        }
    }

    /// 道の色。
    var groundColor: Color {
        switch self {
        case .residential: Color(red: 0.60, green: 0.59, blue: 0.57)
        case .shopping: Color(red: 0.56, green: 0.53, blue: 0.52)
        case .forest: Color(red: 0.46, green: 0.42, blue: 0.34)
        case .snow: Color(red: 0.86, green: 0.88, blue: 0.91)
        case .hotel: Color(red: 0.40, green: 0.39, blue: 0.42)
        case .palace: Color(red: 0.44, green: 0.38, blue: 0.34)
        case .reception: Color(red: 0.30, green: 0.28, blue: 0.30)
        }
    }

    /// 道の両脇に立っているものの色。
    var propColor: Color {
        switch self {
        case .residential: Color(red: 0.78, green: 0.74, blue: 0.68)
        case .shopping: Color(red: 0.70, green: 0.46, blue: 0.38)
        case .forest: Color(red: 0.24, green: 0.38, blue: 0.28)
        case .snow: Color(red: 0.70, green: 0.74, blue: 0.80)
        case .hotel: Color(red: 0.52, green: 0.50, blue: 0.56)
        case .palace: Color(red: 0.66, green: 0.56, blue: 0.34)
        case .reception: Color(red: 0.42, green: 0.38, blue: 0.42)
        }
    }

    /// 屋根の下かどうか。天気の影響を受けなくなる。
    var isSheltered: Bool {
        switch self {
        case .palace, .reception: true
        default: false
        }
    }
}
