import Foundation

/// 端末に保存される、並んでいる人の全記録。
struct QueueState: Codable, Equatable {
    /// 初めてこの列に並んだ日。
    var joinedAt: Date
    /// 今の周回に並び始めた日。
    var lapStartedAt: Date
    /// 進捗を計算する基準の時刻。
    var anchorDate: Date
    /// 基準時刻での進捗。0 が最後尾、QueueWorld.length が受付。
    var anchorProgress: Int
    /// 何周目か。
    var lap: Int
    /// これまでに割り込まれた合計人数。
    var totalCutIns: Int
    /// これまでに追い抜いた合計人数。
    var totalSkipped: Int
    /// 前の人に絡んだ合計回数。
    var totalInteractions: Int
    /// 次に発行する整理券の通し番号。
    var nextTicketNumber: Int
    /// 受け取った景品。
    var collected: [CollectedPrize]

    static func initial(now: Date = .now) -> QueueState {
        QueueState(
            joinedAt: now,
            lapStartedAt: now,
            anchorDate: now,
            anchorProgress: 0,
            lap: 1,
            totalCutIns: 0,
            totalSkipped: 0,
            totalInteractions: 0,
            nextTicketNumber: 1,
            collected: []
        )
    }
}

/// 受付で受け取った景品の控え。
struct CollectedPrize: Codable, Equatable, Identifiable {
    let id: UUID
    /// 景品カタログ上の識別子。
    let prizeID: String
    let receivedAt: Date
    /// 整理券の通し番号。この景品を受け取った唯一の証明になる。
    let ticketNumber: Int
    /// 何周目に受け取ったか。
    let lap: Int
    /// 並んでいた時間。
    let hoursWaited: Int
    /// 受け取った日の天候。
    let weather: QueueWeather
}
