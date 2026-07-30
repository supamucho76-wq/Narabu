import Foundation

/// 集中力。連打だけで進めないようにするための目安。
///
/// 減っても操作は止めない。成功しにくくなり、報われかたが小さくなるだけ。
/// 「切れたので何分待つ」という作りには絶対にしない。
enum FocusGauge {
    static let maximum: Double = 100
    /// 1秒あたりの自然回復。0からでも1分かからずに戻る。
    static let regenPerSecond: Double = 2.2

    /// アクション1回の消費。強い手ほど気を使う。
    static func cost(for action: QueueAction) -> Double {
        switch action {
        case .tapShoulder: 7
        case .talk: 10
        case .surprise: 15
        case .cheer: 8
        case .highFive: 12
        }
    }

    /// 保存した値と時刻から、今の集中力を求める。
    ///
    /// 画面の中で数えるのではなく時刻から逆算するので、
    /// アプリを閉じている間も回復している。
    static func current(anchor: Double, anchorDate: Date, now: Date) -> Double {
        let elapsed = max(0, now.timeIntervalSince(anchorDate))
        return min(maximum, max(0, anchor + elapsed * regenPerSecond))
    }

    /// 0から1の割合。成功率と報酬の目減りに使う。
    static func ratio(_ focus: Double) -> Double {
        min(1, max(0, focus / maximum))
    }

    /// 集中が切れているときに落ちる成功率。
    ///
    /// 半分を切ったあたりからじわじわ効き始める。
    static func successPenalty(_ focus: Double) -> Double {
        let ratio = ratio(focus)
        guard ratio < 0.5 else { return 0 }
        return (0.5 - ratio) * 0.6
    }

    /// 集中が切れていると、進める人数も1人減る。
    static func advancePenalty(_ focus: Double) -> Int {
        ratio(focus) < 0.25 ? 1 : 0
    }
}
