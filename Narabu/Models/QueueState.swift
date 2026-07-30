import Foundation

/// 端末に保存される、プレイヤーの全記録。
///
/// あとから項目を足しても古い保存データが読めなくならないよう、
/// 復元は項目ごとに既定値つきで行う。
struct QueueState: Codable, Equatable {
    /// 初めて遊び始めた日。
    var joinedAt: Date

    // MARK: - 挑戦中のステージ

    /// 何番目のステージに挑んでいるか。1 始まり。
    var stageNumber: Int
    /// 何周目か。一周するとステージが長くなって戻ってくる。
    var lap: Int
    /// このステージに並び始めた時刻。
    var stageStartedAt: Date
    /// 進捗を計算する基準の時刻。
    var anchorDate: Date
    /// 基準時刻での進捗。0 が最後尾、ステージの人数ぶん進むとクリア。
    var anchorProgress: Int

    // MARK: - 記録

    var totalCutIns: Int
    var totalSkipped: Int
    var totalInteractions: Int
    var nextTicketNumber: Int
    var collected: [CollectedPrize]
    /// クリアしたことのあるステージ番号。
    var clearedStages: Set<Int>

    // MARK: - 持ち物と育成

    /// ごぼう抜きアイテムと、その個数。
    var inventory: [String: Int]
    var hasDrawnStarterGacha: Bool
    var lastFreeGachaAt: Date?
    /// 未使用のガチャチケット。待たずに引ける。
    var gachaTickets: Int
    var coins: Int
    /// 手に入れた装備。
    var ownedEquipment: Set<String>
    /// 部位ごとに今つけている装備。
    var equipped: [String: String]
    /// 覚えたスキルと、その段階。
    var skillLevels: [String: Int]

    static func initial(now: Date = .now) -> QueueState {
        QueueState(
            joinedAt: now,
            stageNumber: 1,
            lap: 1,
            stageStartedAt: now,
            anchorDate: now,
            anchorProgress: 0,
            totalCutIns: 0,
            totalSkipped: 0,
            totalInteractions: 0,
            nextTicketNumber: 1,
            collected: [],
            clearedStages: [],
            inventory: [:],
            hasDrawnStarterGacha: false,
            lastFreeGachaAt: nil,
            gachaTickets: 0,
            coins: 0,
            ownedEquipment: [],
            equipped: [:],
            skillLevels: [:]
        )
    }

    // MARK: - 復元

    init(
        joinedAt: Date,
        stageNumber: Int,
        lap: Int,
        stageStartedAt: Date,
        anchorDate: Date,
        anchorProgress: Int,
        totalCutIns: Int,
        totalSkipped: Int,
        totalInteractions: Int,
        nextTicketNumber: Int,
        collected: [CollectedPrize],
        clearedStages: Set<Int>,
        inventory: [String: Int],
        hasDrawnStarterGacha: Bool,
        lastFreeGachaAt: Date?,
        gachaTickets: Int,
        coins: Int,
        ownedEquipment: Set<String>,
        equipped: [String: String],
        skillLevels: [String: Int]
    ) {
        self.joinedAt = joinedAt
        self.stageNumber = stageNumber
        self.lap = lap
        self.stageStartedAt = stageStartedAt
        self.anchorDate = anchorDate
        self.anchorProgress = anchorProgress
        self.totalCutIns = totalCutIns
        self.totalSkipped = totalSkipped
        self.totalInteractions = totalInteractions
        self.nextTicketNumber = nextTicketNumber
        self.collected = collected
        self.clearedStages = clearedStages
        self.inventory = inventory
        self.hasDrawnStarterGacha = hasDrawnStarterGacha
        self.lastFreeGachaAt = lastFreeGachaAt
        self.gachaTickets = gachaTickets
        self.coins = coins
        self.ownedEquipment = ownedEquipment
        self.equipped = equipped
        self.skillLevels = skillLevels
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let now = Date.now

        joinedAt = try container.decodeIfPresent(Date.self, forKey: .joinedAt) ?? now
        stageNumber = try container.decodeIfPresent(Int.self, forKey: .stageNumber) ?? 1
        lap = try container.decodeIfPresent(Int.self, forKey: .lap) ?? 1
        stageStartedAt = try container.decodeIfPresent(Date.self, forKey: .stageStartedAt) ?? now
        anchorDate = try container.decodeIfPresent(Date.self, forKey: .anchorDate) ?? now
        // ステージ制より前の進捗は数える対象が違うので、引き継がず最初から並び直す。
        let isBeforeStages = !container.contains(.stageNumber)
        anchorProgress = isBeforeStages
            ? 0
            : (try container.decodeIfPresent(Int.self, forKey: .anchorProgress) ?? 0)

        totalCutIns = try container.decodeIfPresent(Int.self, forKey: .totalCutIns) ?? 0
        totalSkipped = try container.decodeIfPresent(Int.self, forKey: .totalSkipped) ?? 0
        totalInteractions = try container.decodeIfPresent(Int.self, forKey: .totalInteractions) ?? 0
        nextTicketNumber = try container.decodeIfPresent(Int.self, forKey: .nextTicketNumber) ?? 1
        collected = try container.decodeIfPresent([CollectedPrize].self, forKey: .collected) ?? []
        clearedStages = try container.decodeIfPresent(Set<Int>.self, forKey: .clearedStages) ?? []

        inventory = try container.decodeIfPresent([String: Int].self, forKey: .inventory) ?? [:]
        hasDrawnStarterGacha = try container.decodeIfPresent(Bool.self, forKey: .hasDrawnStarterGacha) ?? false
        lastFreeGachaAt = try container.decodeIfPresent(Date.self, forKey: .lastFreeGachaAt)
        gachaTickets = try container.decodeIfPresent(Int.self, forKey: .gachaTickets) ?? 0
        coins = try container.decodeIfPresent(Int.self, forKey: .coins) ?? 0
        ownedEquipment = try container.decodeIfPresent(Set<String>.self, forKey: .ownedEquipment) ?? []
        equipped = try container.decodeIfPresent([String: String].self, forKey: .equipped) ?? [:]
        skillLevels = try container.decodeIfPresent([String: Int].self, forKey: .skillLevels) ?? [:]
    }
}

/// ステージをクリアしたときに受け取った記念品の控え。
struct CollectedPrize: Codable, Equatable, Identifiable {
    let id: UUID
    let prizeID: String
    let receivedAt: Date
    /// 整理券の通し番号。
    let ticketNumber: Int
    /// どのステージで受け取ったか。
    let stageNumber: Int
    /// 並んでいた時間。
    let minutesWaited: Int
}
