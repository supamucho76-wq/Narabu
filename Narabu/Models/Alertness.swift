import SwiftUI

/// 周りからの警戒。乱暴に進むほど上がる。
///
/// 「どけ！」を連打するだけで攻略できないようにするための重り。
/// 強引に行くか、丁寧に行くかを選ばせるのがねらい。
enum Alertness {
    static let maximum: Double = 100

    /// 何もしないでいると、少しずつ収まる。
    static let calmPerSecond: Double = 0.6

    enum Level: Sendable {
        case calm
        case watched
        case dangerous

        var label: String {
            switch self {
            case .calm: "警戒なし"
            case .watched: "見られている"
            case .dangerous: "警備員が近い"
            }
        }

        var color: Color {
            switch self {
            case .calm: Color(red: 0.52, green: 0.78, blue: 0.60)
            case .watched: Color(red: 0.94, green: 0.76, blue: 0.30)
            case .dangerous: Color(red: 0.92, green: 0.36, blue: 0.30)
            }
        }

        /// 乱暴な手が通りにくくなる度合い。
        var roughPenalty: Double {
            switch self {
            case .calm: 0
            case .watched: 0.2
            case .dangerous: 0.45
            }
        }
    }

    static func level(_ value: Double) -> Level {
        switch value {
        case ..<35: .calm
        case ..<70: .watched
        default: .dangerous
        }
    }

    /// 保存した値と時刻から、今の警戒度を求める。
    static func current(anchor: Double, anchorDate: Date, now: Date) -> Double {
        let elapsed = max(0, now.timeIntervalSince(anchorDate))
        return min(maximum, max(0, anchor - elapsed * calmPerSecond))
    }

    /// 警備員に連れ戻される確率。警戒度が振り切れているときだけ起きる。
    static func guardChance(_ value: Double) -> Double {
        guard value >= 85 else { return 0 }
        return (value - 85) / 15 * 0.35
    }
}
