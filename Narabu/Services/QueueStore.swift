import Foundation
import Observation

/// 遊んでいる状態のすべてを保持する。
///
/// 進捗は保存せず、基準時刻からの経過で毎回計算する。
/// アプリを消していた間も列は進んでいる。
@MainActor
@Observable
final class QueueStore {
    private(set) var state: QueueState
    /// 表示を更新するための現在時刻。
    private(set) var now: Date = .now

    private let fileURL: URL
    private var ticker: Task<Void, Never>?

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        state = Self.load(from: self.fileURL) ?? .initial()
        save()
    }

    // MARK: - 挑戦中のステージ

    var stage: Stage {
        StageCatalog.stage(number: state.stageNumber, lap: state.lap)
    }

    /// 最後尾から何人ぶん進んだか。
    var progress: Int {
        min(stage.queueLength, QueueEngine.progress(
            anchorProgress: state.anchorProgress,
            anchorDate: state.anchorDate,
            at: now,
            limit: stage.queueLength
        ))
    }

    /// 先頭までの残り人数。
    var remaining: Int { stage.queueLength - progress }

    var hasClearedStage: Bool { remaining <= 0 }

    /// 今いる場所。
    var scene: SceneKind { stage.scene(atProgress: progress) }

    /// このステージに並んでいる時間（分）。
    var minutesInStage: Int {
        max(0, Int(now.timeIntervalSince(state.stageStartedAt) / 60))
    }

    /// すぐ前に並んでいる人。
    var personAhead: QueuePerson {
        PersonFactory.person(atQueueIndex: max(0, remaining - 1), scene: scene)
    }

    /// これまでに割り込まれた合計人数。
    var totalCutIns: Int {
        state.totalCutIns + QueueEngine.cutInCount(from: state.anchorDate, to: now)
    }

    // MARK: - 装備とスキル

    /// 装備とスキルから集まる効果。すべての計算はこの値を見る。
    var effects: LoadoutEffects {
        var parts: [LoadoutEffects] = []

        for (slot, id) in state.equipped {
            guard EquipmentSlot(rawValue: slot) != nil,
                  let equipment = EquipmentCatalog.equipment(id: id) else { continue }
            parts.append(equipment.effects)
        }
        for (id, level) in state.skillLevels {
            guard let skill = SkillCatalog.skill(id: id) else { continue }
            parts.append(skill.effects(atLevel: level))
        }

        return LoadoutEffects.combine(parts).clamped
    }

    func ownedEquipment(in slot: EquipmentSlot) -> [Equipment] {
        EquipmentCatalog.items(in: slot).filter { state.ownedEquipment.contains($0.id) }
    }

    func equippedItem(in slot: EquipmentSlot) -> Equipment? {
        state.equipped[slot.rawValue].flatMap { EquipmentCatalog.equipment(id: $0) }
    }

    func equip(_ equipment: Equipment) {
        guard state.ownedEquipment.contains(equipment.id) else { return }
        state.equipped[equipment.slot.rawValue] = equipment.id
        save()
    }

    func unequip(_ slot: EquipmentSlot) {
        state.equipped.removeValue(forKey: slot.rawValue)
        save()
    }

    /// 覚えたスキルとその段階。
    var learnedSkills: [(skill: Skill, level: Int)] {
        SkillCatalog.all.compactMap { skill in
            let level = state.skillLevels[skill.id] ?? 0
            return level > 0 ? (skill, level) : nil
        }
    }

    func canUpgrade(_ skill: Skill) -> Bool {
        let level = state.skillLevels[skill.id] ?? 0
        guard level > 0, level < Skill.maxLevel else { return false }
        return state.coins >= Skill.upgradeCost(currentLevel: level)
    }

    func upgrade(_ skill: Skill) {
        guard canUpgrade(skill) else { return }
        let level = state.skillLevels[skill.id] ?? 0
        state.coins -= Skill.upgradeCost(currentLevel: level)
        state.skillLevels[skill.id] = level + 1
        save()
    }

    // MARK: - ガチャとアイテム

    var needsStarterGacha: Bool { !state.hasDrawnStarterGacha }

    /// 無料ガチャが引けるまでの残り時間。引けるなら nil。
    var freeGachaCooldown: TimeInterval? {
        GachaMachine.remainingCooldown(
            lastDrawnAt: state.lastFreeGachaAt,
            now: now,
            multiplier: effects.gachaCooldownMultiplier
        )
    }

    var canDrawFreeGacha: Bool {
        state.hasDrawnStarterGacha && freeGachaCooldown == nil
    }

    /// チケットがあれば待たずに引ける。
    var canDrawWithTicket: Bool { state.gachaTickets > 0 }

    var ownedItems: [(item: GachaItem, count: Int)] {
        GachaCatalog.items.compactMap { item in
            let count = state.inventory[item.id] ?? 0
            return count > 0 ? (item, count) : nil
        }
    }

    func count(of item: GachaItem) -> Int { state.inventory[item.id] ?? 0 }

    func drawStarterGacha() -> [GachaItem] {
        guard needsStarterGacha else { return [] }

        let results = GachaMachine.draw(count: GachaCatalog.starterDrawCount, luck: effects.gachaLuckBonus)
        add(results)
        state.hasDrawnStarterGacha = true
        state.lastFreeGachaAt = now
        save()
        return results
    }

    func drawFreeGacha() -> GachaItem? {
        guard canDrawFreeGacha else { return nil }

        let result = GachaMachine.draw(luck: effects.gachaLuckBonus)
        add([result])
        state.lastFreeGachaAt = now
        save()
        return result
    }

    func drawWithTicket() -> GachaItem? {
        guard state.gachaTickets > 0 else { return nil }

        let result = GachaMachine.draw(luck: effects.gachaLuckBonus)
        add([result])
        state.gachaTickets -= 1
        save()
        return result
    }

    private func add(_ items: [GachaItem]) {
        for item in items {
            state.inventory[item.id, default: 0] += 1
        }
    }

    /// アイテムを使ってごぼう抜きする。実際に追い抜けた人数を返す。
    @discardableResult
    func useItem(_ item: GachaItem) -> Int {
        guard count(of: item) > 0, remaining > 0 else { return 0 }

        let boosted = Int((Double(item.people) * effects.overtakeMultiplier).rounded())
        let skipped = min(boosted, remaining)

        state.inventory[item.id, default: 0] -= 1
        if state.inventory[item.id] == 0 {
            state.inventory.removeValue(forKey: item.id)
        }
        state.totalSkipped += skipped
        moveAnchor(to: progress + skipped)
        save()

        return skipped
    }

    #if DEBUG
    /// 開発中に何度も確認するための巻き戻し。
    func resetForDebugging() {
        state = .initial(now: now)
        save()
    }
    #endif

    // MARK: - ステージの進行

    /// ステージをクリアして報酬を受け取り、次のステージへ進む。
    @discardableResult
    func clearStage() -> StageClearResult? {
        guard hasClearedStage else { return nil }

        let cleared = stage
        let isFirstTime = !state.clearedStages.contains(cleared.id)
        let reward = cleared.reward

        state.coins += reward.coins
        state.gachaTickets += reward.gachaTickets

        var gainedEquipment: Equipment?
        var gainedSkill: Skill?

        if isFirstTime {
            if let id = reward.equipmentID, let equipment = EquipmentCatalog.equipment(id: id) {
                state.ownedEquipment.insert(equipment.id)
                // 空いている部位なら、そのまま着けておく。
                if state.equipped[equipment.slot.rawValue] == nil {
                    state.equipped[equipment.slot.rawValue] = equipment.id
                }
                gainedEquipment = equipment
            }
            if let id = reward.skillID, let skill = SkillCatalog.skill(id: id) {
                state.skillLevels[skill.id] = max(1, state.skillLevels[skill.id] ?? 0)
                gainedSkill = skill
            }
        }

        let souvenir = recordSouvenir(for: cleared)
        state.clearedStages.insert(cleared.id)
        advanceToNextStage()
        save()

        return StageClearResult(
            stage: cleared,
            coins: reward.coins,
            gachaTickets: reward.gachaTickets,
            equipment: gainedEquipment,
            skill: gainedSkill,
            souvenir: souvenir
        )
    }

    /// クリアの記念にもらえる、値打ちのない品。図鑑に残る。
    private func recordSouvenir(for stage: Stage) -> Prize {
        let prize = PrizeCatalog.prize(forLap: state.nextTicketNumber, joinedAt: state.joinedAt)
        state.collected.append(
            CollectedPrize(
                id: UUID(),
                prizeID: prize.id,
                receivedAt: now,
                ticketNumber: state.nextTicketNumber,
                stageNumber: stage.id,
                minutesWaited: minutesInStage
            )
        )
        state.nextTicketNumber += 1
        return prize
    }

    private func advanceToNextStage() {
        if state.stageNumber >= StageCatalog.count {
            state.stageNumber = 1
            state.lap += 1
        } else {
            state.stageNumber += 1
        }
        state.stageStartedAt = now
        moveAnchor(to: 0)
    }

    // MARK: - 前の人への働きかけ

    /// 直前に押したアクションと、その連続回数。同じ手ばかりだと通じなくなる。
    private(set) var lastAction: QueueAction?
    private(set) var repeatCount = 0
    /// 連続で成功している回数。
    private(set) var combo = 0

    /// コンボによる追加の前進。
    var comboBonus: Int { combo >= 5 ? 1 : 0 }

    /// 一定のコンボから、しばらく前進が倍になる。
    var isFever: Bool { combo >= 10 }

    func interactWithPersonAhead(_ action: QueueAction) -> ActionOutcome {
        guard !hasClearedStage else {
            return ActionOutcome(
                grade: .miss,
                message: "もう先頭なので、絡む相手がいない。",
                advance: 0
            )
        }

        let person = personAhead
        state.totalInteractions += 1
        repeatCount = (action == lastAction) ? repeatCount + 1 : 0
        lastAction = action

        var outcome = QueueActions.outcome(
            action: action,
            person: person,
            repeatCount: repeatCount,
            seed: state.totalInteractions &* 31 &+ remaining,
            successBonus: effects.eventSuccessBonus,
            comboBonus: comboBonus
        )

        if isFever, outcome.advance > 0 {
            outcome = ActionOutcome(
                grade: outcome.grade,
                message: outcome.message,
                advance: outcome.advance * 2
            )
        }

        combo = outcome.keepsCombo ? combo + 1 : 0

        if outcome.advance != 0 {
            moveAnchor(to: min(stage.queueLength, max(0, progress + outcome.advance)))
        }
        if outcome.grade == .great {
            state.coins += 3
        }
        save()

        return outcome
    }

    // MARK: - ミッション

    /// いま挑戦できるミッション。常にひとつある。
    private(set) var currentMission: Mission?

    /// 手持ちのミッションがなければ用意する。
    func ensureMission() {
        guard currentMission == nil else { return }
        currentMission = MissionFactory.make(
            seed: state.totalInteractions &* 7 &+ state.stageNumber &* 101 &+ Int(now.timeIntervalSince1970) / 17,
            stage: stage
        )
    }

    /// ミッションの結果を反映して、次のミッションを用意する。
    func completeMission(_ mission: Mission, success: Bool) {
        let advance = success ? mission.reward : mission.consolationReward
        let coins = success ? mission.coins : mission.consolationCoins

        state.coins += coins
        combo = success ? combo + 1 : 0

        if advance > 0 {
            moveAnchor(to: min(stage.queueLength, progress + advance))
        }

        currentMission = nil
        save()
        ensureMission()
    }

    /// 課金して前の人を追い抜く。
    func skipAhead(by people: Int) {
        state.totalSkipped += people
        moveAnchor(to: min(stage.queueLength, progress + people))
        save()
    }

    /// 基準を今に張り直す。割り込まれた人数は先に確定させてから移す。
    private func moveAnchor(to newProgress: Int) {
        state.totalCutIns = totalCutIns
        state.anchorDate = now
        state.anchorProgress = newProgress
    }

    // MARK: - 時刻の更新

    func startTicking() {
        guard ticker == nil else { return }
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                self?.refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func stopTicking() {
        ticker?.cancel()
        ticker = nil
    }

    func refresh() {
        now = .now
    }

    // MARK: - 保存

    private func save() {
        do {
            let data = try JSONEncoder().encode(state)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // 保存できなくても遊び続けられるほうが大事なので、握りつぶす。
        }
    }

    private static func load(from url: URL) -> QueueState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(QueueState.self, from: data)
    }

    private static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("queue-state.json")
    }
}

/// ステージをクリアしたときに手に入ったもの。
struct StageClearResult: Equatable {
    let stage: Stage
    let coins: Int
    let gachaTickets: Int
    let equipment: Equipment?
    let skill: Skill?
    let souvenir: Prize
}
