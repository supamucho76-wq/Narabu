import Foundation

/// 端末に保存される、並んでいる人の全記録。
///
/// あとから項目を足しても古い保存データが読めなくならないよう、
/// 復元は項目ごとに既定値つきで行う。
struct QueueState: Codable, Equatable {
    /// 初めてこの列に並んだ日。
    var joinedAt: Date
    /// 今の周回に並び始めた日。
    var lapStartedAt: Date
    /// 進捗を計算する基準の時刻。
    var anchorDate: Date
    /// 基準時刻での進捗。0 が最後尾、QueueWorld.length が店の前。
    var anchorProgress: Int
    /// 何周目か。
    var lap: Int
    /// これまでに割り込まれた合計人数。
    var totalCutIns: Int
    /// これまでにアイテムで追い抜いた合計人数。
    var totalSkipped: Int
    /// 前の人に絡んだ合計回数。
    var totalInteractions: Int
    /// 次に発行する整理券の通し番号。
    var nextTicketNumber: Int
    /// 受け取った景品。
    var collected: [CollectedPrize]

    /// 所持しているごぼう抜きアイテムと、その個数。
    var inventory: [String: Int]
    /// 初回のスタートダッシュ5連を引いたか。
    var hasDrawnStarterGacha: Bool
    /// 最後に無料ガチャを引いた時刻。
    var lastFreeGachaAt: Date?

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
            collected: [],
            inventory: [:],
            hasDrawnStarterGacha: false,
            lastFreeGachaAt: nil
        )
    }

    // MARK: - 復元

    init(
        joinedAt: Date,
        lapStartedAt: Date,
        anchorDate: Date,
        anchorProgress: Int,
        lap: Int,
        totalCutIns: Int,
        totalSkipped: Int,
        totalInteractions: Int,
        nextTicketNumber: Int,
        collected: [CollectedPrize],
        inventory: [String: Int],
        hasDrawnStarterGacha: Bool,
        lastFreeGachaAt: Date?
    ) {
        self.joinedAt = joinedAt
        self.lapStartedAt = lapStartedAt
        self.anchorDate = anchorDate
        self.anchorProgress = anchorProgress
        self.lap = lap
        self.totalCutIns = totalCutIns
        self.totalSkipped = totalSkipped
        self.totalInteractions = totalInteractions
        self.nextTicketNumber = nextTicketNumber
        self.collected = collected
        self.inventory = inventory
        self.hasDrawnStarterGacha = hasDrawnStarterGacha
        self.lastFreeGachaAt = lastFreeGachaAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let now = Date.now

        joinedAt = try container.decodeIfPresent(Date.self, forKey: .joinedAt) ?? now
        lapStartedAt = try container.decodeIfPresent(Date.self, forKey: .lapStartedAt) ?? now
        anchorDate = try container.decodeIfPresent(Date.self, forKey: .anchorDate) ?? now
        anchorProgress = try container.decodeIfPresent(Int.self, forKey: .anchorProgress) ?? 0
        lap = try container.decodeIfPresent(Int.self, forKey: .lap) ?? 1
        totalCutIns = try container.decodeIfPresent(Int.self, forKey: .totalCutIns) ?? 0
        totalSkipped = try container.decodeIfPresent(Int.self, forKey: .totalSkipped) ?? 0
        totalInteractions = try container.decodeIfPresent(Int.self, forKey: .totalInteractions) ?? 0
        nextTicketNumber = try container.decodeIfPresent(Int.self, forKey: .nextTicketNumber) ?? 1
        collected = try container.decodeIfPresent([CollectedPrize].self, forKey: .collected) ?? []
        inventory = try container.decodeIfPresent([String: Int].self, forKey: .inventory) ?? [:]
        hasDrawnStarterGacha = try container.decodeIfPresent(Bool.self, forKey: .hasDrawnStarterGacha) ?? false
        lastFreeGachaAt = try container.decodeIfPresent(Date.self, forKey: .lastFreeGachaAt)
    }
}

/// 店で受け取った景品の控え。
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
