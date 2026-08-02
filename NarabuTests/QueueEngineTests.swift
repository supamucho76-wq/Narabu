import XCTest
@testable import Narabu

/// 排出率の検証を毎回同じ結果にするための乱数。
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

/// QueueStore は画面と同じ場所で動くので、試験もそこに合わせる。
@MainActor
final class QueueEngineTests: XCTestCase {
    private let noon = Date(timeIntervalSince1970: 1_760_000_000)

    // MARK: - 列の進みかた

    func testSameIntervalAlwaysProducesSameResult() {
        let later = noon.addingTimeInterval(3_600 * 5)
        XCTAssertEqual(
            QueueEngine.servedCount(from: noon, to: later),
            QueueEngine.servedCount(from: noon, to: later),
            "同じ区間を何度計算しても結果が変わってはいけない"
        )
    }

    func testQueueAdvancesAsTimePasses() {
        let oneHour = QueueEngine.servedCount(from: noon, to: noon.addingTimeInterval(3_600))
        let twoHours = QueueEngine.servedCount(from: noon, to: noon.addingTimeInterval(7_200))
        XCTAssertGreaterThan(oneHour, 0)
        XCTAssertGreaterThan(twoHours, oneHour)
    }

    func testQueueNeverMovesBackwardForPastDates() {
        XCTAssertEqual(QueueEngine.servedCount(from: noon, to: noon.addingTimeInterval(-3_600)), 0)
        XCTAssertEqual(QueueEngine.cutInCount(from: noon, to: noon.addingTimeInterval(-3_600)), 0)
    }

    func testCutInCountNeverDecreases() {
        var previous = 0
        for hours in stride(from: 0, through: 48, by: 3) {
            let count = QueueEngine.cutInCount(
                from: noon,
                to: noon.addingTimeInterval(Double(hours) * 3_600)
            )
            XCTAssertGreaterThanOrEqual(count, previous, "\(hours)時間後に割り込み数が減っている")
            previous = count
        }
    }

    /// 自動前進はあくまで補助。速すぎると、遊ぶ前にステージが終わってしまう。
    func testPassiveAdvanceIsOnlyATrickle() {
        let perHour = QueueEngine.servedCountExact(from: noon, to: noon.addingTimeInterval(3_600))
        let secondsPerPerson = 3_600 / perHour
        XCTAssertGreaterThan(secondsPerPerson, 40, "自動で進みすぎて操作する意味がなくなる")
        XCTAssertLessThan(secondsPerPerson, 240, "遅すぎると止まって見える")
    }

    /// どれだけ放置しても、自動前進だけではステージが終わらないこと。
    ///
    /// ここが崩れると、久しぶりに開いた人がいきなりクリア画面を見ることになる。
    func testStagesNeverClearThemselvesWhileAway() {
        let store = QueueStore(fileURL: temporaryStateFile())

        for away in [5.0, 60.0, 60 * 24.0, 60 * 24 * 30.0] {
            store.overrideForTesting(anchorProgress: 0, anchorDate: noon, now: noon.addingTimeInterval(away * 60))

            XCTAssertGreaterThan(store.remaining, 0,
                                 "\(Int(away))分離れただけでステージが終わっている")
            XCTAssertFalse(store.hasClearedStage)
            XCTAssertNil(store.clearStage(), "操作していないのにクリアが成立している")
        }
    }

    /// 離れていた時間が長くても、進みは半分までに抑えること。
    func testOfflineProgressIsCapped() {
        let store = QueueStore(fileURL: temporaryStateFile())
        let length = store.stage.queueLength

        store.overrideForTesting(anchorProgress: 0, anchorDate: noon, now: noon.addingTimeInterval(86_400))
        XCTAssertLessThanOrEqual(store.progress, length / 2 + 1, "放置だけで進みすぎている")
    }

    /// 操作で先頭まで到達したときは、ちゃんとクリアできること。
    func testReachingTheFrontByPlayingStillClears() {
        let store = QueueStore(fileURL: temporaryStateFile())
        let length = store.stage.queueLength

        store.overrideForTesting(anchorProgress: length, anchorDate: noon, now: noon)
        XCTAssertEqual(store.remaining, 0)
        XCTAssertTrue(store.hasClearedStage)
        XCTAssertNotNil(store.clearStage())
    }

    func testRemainingNeverGoesNegative() {
        let store = QueueStore(fileURL: temporaryStateFile())

        for progress in [-50, 0, 5, 9_999] {
            store.overrideForTesting(anchorProgress: progress, anchorDate: noon, now: noon.addingTimeInterval(9_999))
            XCTAssertGreaterThanOrEqual(store.remaining, 0)
            XCTAssertGreaterThanOrEqual(store.progress, 0)
        }
    }

    private func temporaryStateFile() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("narabu-test-\(UUID().uuidString).json")
    }

    func testProgressStopsAtTheFrontOfTheStage() {
        let progress = QueueEngine.progress(
            anchorProgress: 0,
            anchorDate: noon,
            at: noon.addingTimeInterval(86_400),
            limit: 30
        )
        XCTAssertEqual(progress, 30)
    }

    // MARK: - ステージ

    func testStagesGetLongerAsYouGo() {
        var previous = 0
        for stage in StageCatalog.stages {
            XCTAssertGreaterThan(stage.queueLength, previous, "\(stage.name)が前より短い")
            previous = stage.queueLength
        }
    }

    func testStagesMatchTheSpecifiedSizes() {
        let sizes = StageCatalog.stages.map(\.queueLength)
        XCTAssertEqual(sizes, [10, 30, 80, 150, 300, 500, 1_000])
    }

    // MARK: - アクション

    /// **どの手を押しても必ず前に進むこと。**
    ///
    /// 押すたびに後退する作りだと、連続が積み上がる前に折れてしまい、
    /// 気持ちよさが立ち上がらない。相性は進む量に出す。
    func testEveryActionAlwaysMovesYouForward() {
        for index in 0..<120 {
            let person = PersonFactory.person(atQueueIndex: index, scene: .shopping)

            for action in QueueAction.allCases {
                let outcome = QueueActions.outcome(
                    action: action, person: person, repeatCount: 0, seed: index
                )
                XCTAssertGreaterThan(outcome.advance, 0,
                                     "\(action.label)で進めない相手がいる")
                XCTAssertTrue(outcome.keepsCombo, "アクションで連続が切れている")
            }
        }
    }

    /// 相手に合った手ほど大きく進むこと。読む甲斐があること。
    func testReadingThePersonPaysOff() {
        let person = PersonFactory.person(atQueueIndex: 7, scene: .shopping)
        let personality = person.personality

        func advance(_ action: QueueAction) -> Int {
            QueueActions.outcome(action: action, person: person, repeatCount: 0, seed: 1).advance
        }

        XCTAssertGreaterThan(advance(personality.best), advance(personality.worst),
                             "最適な手が地雷より伸びていない")
    }

    /// 合わない手の代償が、後退ではなく周りの警戒であること。
    func testTheWrongActionCostsAlertnessInsteadOfProgress() {
        for index in 0..<60 {
            let person = PersonFactory.person(atQueueIndex: index, scene: .venue)
            let worst = QueueActions.outcome(
                action: person.personality.worst, person: person, repeatCount: 0, seed: index
            )

            XCTAssertGreaterThan(worst.advance, 0, "地雷を踏んで後退している")
            XCTAssertGreaterThan(worst.alertDelta, 0, "地雷を踏んでも代償がない")
        }
    }

    /// 同じボタンを連打するだけでは伸びなくなること。
    func testRepeatingTheSameActionStopsPayingWell() {
        let person = PersonFactory.person(atQueueIndex: 12, scene: .forest)
        let action = person.personality.best

        let fresh = (0..<200).reduce(0) { total, seed in
            total + QueueActions.outcome(action: action, person: person, repeatCount: 0, seed: seed).advance
        }
        let tired = (0..<200).reduce(0) { total, seed in
            total + QueueActions.outcome(action: action, person: person, repeatCount: 4, seed: seed).advance
        }

        XCTAssertGreaterThan(fresh, tired, "連打しても進みが落ちていない")
    }

    func testEveryPersonalityHasADistinctBestAndWorstAction() {
        for personality in Personality.allCases {
            XCTAssertNotEqual(personality.best, personality.worst,
                              "\(personality.label)の最適解と地雷が同じ")
            XCTAssertFalse(personality.hint.isEmpty, "\(personality.label)に手がかりがない")
        }
    }

    /// 人物情報は説明で終わらせず、攻め方の材料になっていること。
    func testEveryPersonalityTellsHowToApproachThem() {
        for personality in Personality.allCases {
            XCTAssertFalse(personality.tactic.isEmpty, "\(personality.label)に攻め方の手がかりがない")
            XCTAssertNotEqual(personality.tactic, personality.hint,
                              "\(personality.label)の手がかりと攻め方が同じ文になっている")
            // 「肩を叩く」のような答えそのものは書かない。
            for action in QueueAction.allCases {
                XCTAssertFalse(personality.tactic.contains(action.label),
                               "\(personality.label)の攻め方に答えがそのまま書かれている")
            }
        }
    }

    // MARK: - ミッション

    /// アイテムが尽きても遊べるよう、ミッションは必ず作れること。
    func testMissionsAreAlwaysAvailableAndRewarding() {
        for seed in 0..<200 {
            let mission = MissionFactory.make(seed: seed, stage: StageCatalog.stages[0])
            XCTAssertGreaterThan(mission.reward, 0, "達成しても進めないミッションがある")
            XCTAssertGreaterThan(mission.coins, 0)
            XCTAssertFalse(mission.instruction.isEmpty)
        }
    }

    /// 用意した遊びかたが全部そろっていて、どれも実際に出てくること。
    ///
    /// 数分で「またこれか」にならないための下限。
    func testEveryMissionFamilyAppears() {
        var seen: Set<MissionFamily> = []

        for stage in StageCatalog.stages {
            for seed in 0..<400 {
                seen.insert(MissionFactory.make(seed: seed, stage: stage).family)
            }
        }

        XCTAssertEqual(seen.count, MissionFamily.allCases.count,
                       "出てこない遊びかたがある：\(MissionFamily.allCases.filter { !seen.contains($0) })")
        XCTAssertGreaterThanOrEqual(MissionFamily.allCases.count, 13, "遊びかたの種類が減っている")
    }

    /// 同じ遊びが続けて出ないこと。
    ///
    /// 「詰めるタイミングが5回続く」のが一番飽きる形なので、
    /// 直前に出たものは候補から外している。
    func testSameMissionNeverRepeatsBackToBack() {
        for stage in StageCatalog.stages {
            var recent: [MissionFamily] = []
            var previous: MissionFamily?

            for seed in 0..<500 {
                let mission = MissionFactory.make(seed: seed, stage: stage, recent: recent)
                XCTAssertNotEqual(mission.family, previous,
                                  "\(stage.name)で同じ遊びが続けて出た：\(mission.family)")

                previous = mission.family
                recent.append(mission.family)
                if recent.count > MissionFactory.historyDepth {
                    recent.removeFirst(recent.count - MissionFactory.historyDepth)
                }
            }
        }
    }

    /// 2種類が交互に続くのも防げていること。
    func testMissionsDoNotAlternateBetweenTwoKinds() {
        var recent: [MissionFamily] = []
        var history: [MissionFamily] = []

        for seed in 0..<300 {
            let mission = MissionFactory.make(seed: seed, stage: StageCatalog.stages[0], recent: recent)
            history.append(mission.family)
            recent.append(mission.family)
            if recent.count > MissionFactory.historyDepth {
                recent.removeFirst(recent.count - MissionFactory.historyDepth)
            }
        }

        for index in 2..<history.count {
            XCTAssertNotEqual(history[index], history[index - 2],
                              "1つ飛ばしで同じ遊びが戻ってきている")
        }
    }

    /// その場所らしい遊びが多く出ること。
    func testStagesFavourTheirOwnKindOfMission() {
        func share(of family: MissionFamily, on stage: Stage) -> Double {
            let hits = (0..<800).filter {
                MissionFactory.make(seed: $0, stage: stage).family == family
            }.count
            return Double(hits) / 800
        }

        let venue = StageCatalog.stages[4]
        let convenience = StageCatalog.stages[0]

        XCTAssertGreaterThan(share(of: .hide, on: venue), share(of: .hide, on: convenience),
                             "係員の厳しい場所で、やり過ごしが増えていない")
        XCTAssertGreaterThan(share(of: .align, on: venue), share(of: .align, on: convenience),
                             "整理券が要る場所で、整理券の出番が増えていない")
        XCTAssertGreaterThan(share(of: .weave, on: venue), share(of: .weave, on: convenience),
                             "人が詰まっている場所で、すり抜けが増えていない")
    }

    /// 進むほど難しくなるが、手が届かない設定にはしないこと。
    func testMissionsStayPlayableOnLaterStages() {
        for stage in StageCatalog.stages {
            for seed in 0..<300 {
                switch MissionFactory.make(seed: seed, stage: stage).kind {
                case .timing(let width, let speed):
                    XCTAssertGreaterThanOrEqual(width, 0.10, "\(stage.name)の当たり範囲が狭すぎる")
                    XCTAssertLessThanOrEqual(speed, 2.0, "\(stage.name)の針が速すぎる")
                case .jump(let speed, let window):
                    XCTAssertGreaterThanOrEqual(window, 0.10)
                    XCTAssertLessThanOrEqual(speed, 1.5)
                case .align(let tolerance):
                    XCTAssertGreaterThanOrEqual(tolerance, 0.06)
                case .mash(let taps, let seconds):
                    XCTAssertLessThanOrEqual(Double(taps) / seconds, 4.5, "連打が速すぎる")
                case .swipe(let count, let seconds):
                    XCTAssertLessThanOrEqual(Double(count) / seconds, 1.6, "スワイプが忙しすぎる")
                case .dodge(let seconds), .escalator(let seconds), .hide(let seconds):
                    XCTAssertGreaterThan(seconds, 3)
                    XCTAssertLessThanOrEqual(seconds, 12, "1回が長すぎてテンポが死ぬ")
                case .hold(let target, let tolerance):
                    XCTAssertGreaterThanOrEqual(tolerance, 0.06)
                    // 帯が端からはみ出すと、狙いようがなくなる。
                    XCTAssertLessThanOrEqual(target + tolerance, 1.0, "\(stage.name)の帯が端を越えている")
                    XCTAssertGreaterThanOrEqual(target - tolerance, 0.0)
                case .pluck(let count, let seconds):
                    XCTAssertLessThanOrEqual(Double(count) / seconds, 1.4, "拾うのが忙しすぎる")
                case .weave(let count, let seconds):
                    XCTAssertLessThanOrEqual(Double(count) / seconds, 2.4, "交互タップが速すぎる")
                case .trace(let seconds, let width):
                    XCTAssertGreaterThan(seconds, 3)
                    XCTAssertGreaterThanOrEqual(width, 0.12, "\(stage.name)の道が細すぎる")
                case .balance(let seconds, let drift):
                    XCTAssertGreaterThan(seconds, 3)
                    XCTAssertLessThanOrEqual(drift, 1.3, "傾きが速すぎて立て直せない")
                }
            }
        }
    }

    /// どの遊びにも、何をすればいいかの一言があること。
    func testEveryMissionExplainsItself() {
        for stage in StageCatalog.stages {
            for seed in 0..<200 {
                let mission = MissionFactory.make(seed: seed, stage: stage)
                XCTAssertFalse(mission.title.isEmpty)
                XCTAssertFalse(mission.instruction.isEmpty)
            }
        }
    }

    /// 列の先に見える店が、進むほど大きくなること。
    ///
    /// 何のために並んでいるかが常に見えていないと、ただの道になってしまう。
    func testDestinationGrowsAsYouApproach() {
        func size(at ratio: Double) -> Double {
            // QueueWorldView が使っているのと同じ式。
            0.10 + pow(ratio, 1.7) * 0.62
        }

        var previous = 0.0
        for step in stride(from: 0.0, through: 1.0, by: 0.1) {
            let current = size(at: step)
            XCTAssertGreaterThanOrEqual(current, previous, "進んだのに店が大きくならない")
            previous = current
        }

        XCTAssertGreaterThan(size(at: 1.0), size(at: 0.0) * 4, "着く直前でも小さすぎる")
    }

    /// どこに着いたのかが必ず言葉で分かること。
    func testEveryStageDescribesItsArrival() {
        for stage in StageCatalog.stages {
            XCTAssertFalse(stage.arrivalHeadline.isEmpty, "\(stage.name)に到着の見出しがない")
            XCTAssertFalse(stage.arrivalStory.isEmpty, "\(stage.name)に到着の情景がない")
            XCTAssertFalse(stage.openingNote.isEmpty, "\(stage.name)に並び始めの一言がない")
            XCTAssertNotEqual(stage.arrivalHeadline, stage.name,
                              "\(stage.name)の見出しが名前のままで、着いた感じがない")
        }
    }

    /// 周回しても到着の言葉が消えないこと。
    func testArrivalTextSurvivesLooping() {
        let second = StageCatalog.stage(number: 1, lap: 2)
        XCTAssertFalse(second.arrivalHeadline.isEmpty)
        XCTAssertFalse(second.arrivalStory.isEmpty)
    }

    func testEveryStageHasAtLeastOneScene() {
        for stage in StageCatalog.stages {
            XCTAssertFalse(stage.scenes.isEmpty, "\(stage.name)に景色がない")
        }
    }

    /// 最終ステージだけは、いくつもの景色を通り抜ける。
    func testFinalStageTravelsThroughManyScenes() {
        let final = StageCatalog.stages[StageCatalog.count - 1]
        XCTAssertGreaterThan(final.scenes.count, 3)
        XCTAssertEqual(final.scene(atProgress: 0), final.scenes[0])
        XCTAssertEqual(final.scene(atProgress: final.queueLength - 1), .ramen)
    }

    func testLoopingMakesStagesLonger() {
        let first = StageCatalog.stage(number: 1, lap: 1)
        let second = StageCatalog.stage(number: 1, lap: 2)
        XCTAssertGreaterThan(second.queueLength, first.queueLength)
        XCTAssertEqual(second.name, first.name)
    }

    // MARK: - 装備とスキル

    func testEffectsCombineMultiplicativelyAndAdditively() {
        let combined = LoadoutEffects.combine([
            LoadoutEffects(overtakeMultiplier: 1.5, eventSuccessBonus: 0.04),
            LoadoutEffects(overtakeMultiplier: 2.0, eventSuccessBonus: 0.02)
        ])
        XCTAssertEqual(combined.overtakeMultiplier, 3.0, accuracy: 0.001)
        XCTAssertEqual(combined.eventSuccessBonus, 0.06, accuracy: 0.001)
    }

    func testEffectsAreClampedSoTheyCannotBreakTheGame() {
        let extreme = LoadoutEffects(
            overtakeMultiplier: 999,
            gachaCooldownMultiplier: 0.0001,
            eventSuccessBonus: 5,
            gachaLuckBonus: 9
        ).clamped

        XCTAssertLessThanOrEqual(extreme.overtakeMultiplier, 8)
        XCTAssertGreaterThanOrEqual(extreme.gachaCooldownMultiplier, 0.2)
        XCTAssertLessThanOrEqual(extreme.eventSuccessBonus, 0.35)
        XCTAssertLessThanOrEqual(extreme.gachaLuckBonus, 1.0)
    }

    func testSkillGetsStrongerWithEachLevel() {
        let pressure = SkillCatalog.skill(id: "pressure")!
        let low = pressure.effects(atLevel: 1).overtakeMultiplier
        let high = pressure.effects(atLevel: 5).overtakeMultiplier
        XCTAssertGreaterThan(high, low)
    }

    func testUpgradeCostRisesWithLevel() {
        XCTAssertLessThan(Skill.upgradeCost(currentLevel: 1), Skill.upgradeCost(currentLevel: 4))
    }

    /// 報酬で配る装備とスキルが、実在するものを指しているか。
    func testStageRewardsReferToRealEquipmentAndSkills() {
        for stage in StageCatalog.stages {
            if let id = stage.reward.equipmentID {
                XCTAssertNotNil(EquipmentCatalog.equipment(id: id), "\(stage.name)の装備が存在しない")
            }
            if let id = stage.reward.skillID {
                XCTAssertNotNil(SkillCatalog.skill(id: id), "\(stage.name)のスキルが存在しない")
            }
        }
    }

    // MARK: - 集中力

    /// 減っても操作は止めない。成功しにくくなるだけ。
    func testFocusNeverBlocksPlay() {
        XCTAssertEqual(FocusGauge.successPenalty(FocusGauge.maximum), 0)
        XCTAssertGreaterThan(FocusGauge.successPenalty(0), 0)
        XCTAssertLessThan(FocusGauge.successPenalty(0), 0.4, "切れても勝てなくなるほど下げない")
    }

    /// 待たせる仕組みにしないため、短時間で戻ること。
    func testFocusRefillsWithinAMinute() {
        let refilled = FocusGauge.current(anchor: 0, anchorDate: noon, now: noon.addingTimeInterval(60))
        XCTAssertEqual(refilled, FocusGauge.maximum, accuracy: 0.001)
    }

    /// 満タンから続けて15回は押せること。
    ///
    /// 数回で切れると、連続が積み上がる前に手が止まってしまう。
    func testFocusAllowsALongEnoughRun() {
        let heaviest = QueueAction.allCases.map(FocusGauge.cost(for:)).max() ?? 0
        XCTAssertGreaterThanOrEqual(FocusGauge.maximum / heaviest, 12,
                                    "一番重い手でも12回は続けて押せてほしい")

        let average = QueueAction.allCases.map(FocusGauge.cost(for:)).reduce(0, +)
            / Double(QueueAction.allCases.count)
        XCTAssertGreaterThanOrEqual(FocusGauge.maximum / average, 15,
                                    "満タンから15回も押せない")
    }

    func testFocusStaysWithinBounds() {
        for seconds in stride(from: 0.0, through: 300, by: 11) {
            let value = FocusGauge.current(anchor: 30, anchorDate: noon, now: noon.addingTimeInterval(seconds))
            XCTAssertGreaterThanOrEqual(value, 0)
            XCTAssertLessThanOrEqual(value, FocusGauge.maximum)
        }
    }

    func testEveryActionCostsSomeFocus() {
        for action in QueueAction.allCases {
            XCTAssertGreaterThan(FocusGauge.cost(for: action), 0)
            XCTAssertLessThanOrEqual(FocusGauge.cost(for: action), 8)
        }
    }

    // MARK: - 出来事

    func testEventsAlwaysOfferAChoiceThatMatters() {
        for seed in 0..<200 {
            let event = QueueEventFactory.make(seed: seed, stage: StageCatalog.stages[4])
            XCTAssertGreaterThanOrEqual(event.choices.count, 2, "選択肢が足りない")
            XCTAssertFalse(event.situation.isEmpty)

            // どの出来事にも、何かしら得のある選択肢が要る。
            let hasUpside = event.choices.contains { $0.advance > 0 || $0.coins > 0 || $0.itemID != nil }
            XCTAssertTrue(hasUpside, "\(event.title)に得のある選択肢がない")
        }
    }

    func testEventItemsExist() {
        for seed in 0..<200 {
            let event = QueueEventFactory.make(seed: seed, stage: StageCatalog.stages[0])
            for choice in event.choices {
                if let id = choice.itemID {
                    XCTAssertNotNil(GachaCatalog.item(id: id), "\(event.title)が存在しないアイテムを配ろうとしている")
                }
            }
        }
    }

    // MARK: - 装備と記念品

    func testEveryEquipmentTellsWhereItComesFrom() {
        for equipment in EquipmentCatalog.all {
            XCTAssertFalse(equipment.source.isEmpty, "\(equipment.name)の入手先が空")
            XCTAssertFalse(equipment.detail.isEmpty)
        }
    }

    func testSkillValueLabelsChangeWithLevel() {
        for skill in SkillCatalog.all {
            XCTAssertNotEqual(
                skill.valueLabel(atLevel: 1),
                skill.valueLabel(atLevel: 3),
                "\(skill.name)の効果が段階で変わって見えない"
            )
        }
    }

    /// 隠し効果は、集めた記念品のぶんだけ効くこと。
    func testHiddenPrizeEffectsAccumulate() {
        let withEffects = PrizeCatalog.all.filter { $0.hiddenEffect != nil }
        XCTAssertFalse(withEffects.isEmpty, "隠し効果を持つ記念品がひとつもない")

        let none = PrizeCatalog.hiddenEffects(ownedIDs: [])
        XCTAssertEqual(none.overtakeMultiplier, 1, accuracy: 0.001)

        let all = PrizeCatalog.hiddenEffects(ownedIDs: Set(withEffects.map(\.id)))
        XCTAssertGreaterThan(all.overtakeMultiplier, 1)
        XCTAssertNotNil(withEffects.first?.hiddenEffectLabel)
    }

    // MARK: - ボイス突破

    func testPhraseMatchingPrefersTheLongerWording() {
        XCTAssertEqual(VoicePhrase.match(in: "前に行かせてください"), .maeni)
        XCTAssertEqual(VoicePhrase.match(in: "すみません、通してください"), .tooshite)
        XCTAssertEqual(VoicePhrase.match(in: "どけ"), .doke)
        XCTAssertEqual(VoicePhrase.match(in: "おい"), .oi)
    }

    /// 周りの音を拾っただけで勝手に発動しないこと。
    func testUnrelatedSpeechDoesNotTriggerAnything() {
        XCTAssertNil(VoicePhrase.match(in: ""))
        XCTAssertNil(VoicePhrase.match(in: "今日はいい天気ですね"))
        XCTAssertNil(VoicePhrase.match(in: "ラーメン食べたい"))
    }

    func testPoliteWordsCalmTheCrowdAndRoughOnesDoNot() {
        XCTAssertLessThan(VoicePhrase.sumimasen.alertCost, 0, "丁寧に言っても警戒が下がらない")
        XCTAssertGreaterThan(VoicePhrase.doke.alertCost, 0)
        XCTAssertTrue(VoicePhrase.doke.isRough)
        XCTAssertFalse(VoicePhrase.sumimasen.isRough)
    }

    func testRoughWordsMoveMorePeopleButRiskMore() {
        XCTAssertGreaterThan(
            VoicePhrase.doke.advanceRange.upperBound,
            VoicePhrase.sumimasen.advanceRange.upperBound,
            "強く言っても得がない"
        )
        XCTAssertGreaterThan(
            VoicePhrase.sumimasen.baseChance,
            VoicePhrase.doke.baseChance,
            "丁寧に言うほうが通りやすくないと選ぶ意味がない"
        )
    }

    func testVolumeIsClassifiedAcrossTheRange() {
        XCTAssertEqual(VoiceVolume.of(0.05), .quiet)
        XCTAssertEqual(VoiceVolume.of(0.3), .normal)
        XCTAssertEqual(VoiceVolume.of(0.6), .loud)
        XCTAssertEqual(VoiceVolume.of(0.95), .tooLoud)
    }

    /// 同じ言葉を続けると通らなくなること。
    func testRepeatingTheSamePhraseStopsWorking() {
        let person = PersonFactory.person(atQueueIndex: 3, scene: .shopping)

        func successes(repeatCount: Int) -> Int {
            (0..<300).filter { seed in
                BreakthroughResolver.resolve(
                    phrase: .doke, volume: .loud, person: person,
                    alertness: 0, repeatCount: repeatCount, remaining: 500, seed: seed
                ).succeeded
            }.count
        }

        XCTAssertGreaterThan(successes(repeatCount: 0), successes(repeatCount: 3))
    }

    /// 警戒されると乱暴な手が効かなくなること。
    func testAlertnessBlocksRoughTactics() {
        let person = PersonFactory.person(atQueueIndex: 8, scene: .shopping)

        func successes(alertness: Double) -> Int {
            (0..<300).filter { seed in
                BreakthroughResolver.resolve(
                    phrase: .doke, volume: .loud, person: person,
                    alertness: alertness, repeatCount: 0, remaining: 500, seed: seed
                ).succeeded
            }.count
        }

        XCTAssertGreaterThan(successes(alertness: 0), successes(alertness: 80))
    }

    func testGuardOnlyAppearsWhenAlertnessIsExtreme() {
        XCTAssertEqual(Alertness.guardChance(50), 0)
        XCTAssertEqual(Alertness.guardChance(84), 0)
        XCTAssertGreaterThan(Alertness.guardChance(100), 0)
    }

    func testAlertnessCoolsDownOverTime() {
        let later = Alertness.current(anchor: 60, anchorDate: noon, now: noon.addingTimeInterval(60))
        XCTAssertLessThan(later, 60)
        XCTAssertGreaterThanOrEqual(later, 0)
    }

    /// 進める人数が、残り人数を超えないこと。
    func testBreakthroughNeverOvershootsTheFront() {
        let person = PersonFactory.person(atQueueIndex: 1, scene: .shopping)
        for seed in 0..<200 {
            let outcome = BreakthroughResolver.resolve(
                phrase: .doke, volume: .loud, person: person,
                alertness: 0, repeatCount: 0, remaining: 3, seed: seed
            )
            XCTAssertLessThanOrEqual(outcome.advance, 3)
        }
    }

    // MARK: - 音

    /// 音源ファイルを持たないので、波形が正しく焼けることが前提になる。
    func testToneRendersAudibleSamples() throws {
        let buffer = try XCTUnwrap(ToneSynth.render(
            notes: [.init(frequency: 440, start: 0, duration: 0.2, volume: 0.5, timbre: .sine)],
            duration: 0.25
        ))

        XCTAssertEqual(Double(buffer.frameLength), 0.25 * ToneSynth.sampleRate, accuracy: 2)

        let channel = try XCTUnwrap(buffer.floatChannelData?[0])
        var peak: Float = 0
        for frame in 0..<Int(buffer.frameLength) {
            peak = max(peak, abs(channel[frame]))
            XCTAssertLessThanOrEqual(abs(channel[frame]), 1.0, "音が振り切れている")
        }
        XCTAssertGreaterThan(peak, 0.1, "音が鳴っていない")
    }

    func testEveryScenePicksAMood() {
        for scene in SceneKind.allCases {
            let mood = SceneMood.of(scene)
            XCTAssertGreaterThan(mood.beatDuration, 0)
            XCTAssertFalse(mood.chords.isEmpty)
            XCTAssertFalse(mood.scale.isEmpty)
        }
    }

    func testPitchFollowsTheOctave() {
        XCTAssertEqual(ToneSynth.pitch(semitonesFromA4: 0), 440, accuracy: 0.01)
        XCTAssertEqual(ToneSynth.pitch(semitonesFromA4: 12), 880, accuracy: 0.01)
    }

    // MARK: - ガチャ

    func testDropRatesAddUpToOneHundredPercent() {
        let total = GachaCatalog.items.reduce(0) { $0 + $1.dropRate }
        XCTAssertEqual(total, 1.0, accuracy: 0.0001, "排出率の合計が100%になっていない")
    }

    func testEveryItemIsReachableAndRoughlyMatchesItsRate() {
        var counts: [String: Int] = [:]
        var generator = SeededGenerator(seed: 20_260_731)

        let trials = 40_000
        for _ in 0..<trials {
            counts[GachaMachine.draw(using: &generator).id, default: 0] += 1
        }

        for item in GachaCatalog.items {
            let observed = Double(counts[item.id] ?? 0) / Double(trials)
            XCTAssertEqual(observed, item.dropRate, accuracy: 0.015,
                           "\(item.name)の排出率が設定から離れすぎている")
        }
    }

    /// 運が上がると高レアが出やすくなるか。
    func testLuckShiftsResultsTowardRarerItems() {
        func rareShare(luck: Double) -> Double {
            var generator = SeededGenerator(seed: 4_242)
            let trials = 20_000
            let rare = (0..<trials).filter { _ in
                GachaMachine.draw(luck: luck, using: &generator).rarity.glowStrength > 0.5
            }.count
            return Double(rare) / Double(trials)
        }

        XCTAssertGreaterThan(rareShare(luck: 0.5), rareShare(luck: 0))
    }

    func testCatalogHasTwentyItemsWithUniqueIDs() {
        XCTAssertEqual(GachaCatalog.items.count, 20)
        XCTAssertEqual(Set(GachaCatalog.items.map(\.id)).count, 20, "IDが重複している")
        XCTAssertEqual(GachaCatalog.item(id: "dash")?.people, 5)
        XCTAssertEqual(GachaCatalog.item(id: "bicycle")?.people, 20)
        XCTAssertEqual(GachaCatalog.item(id: "motorbike")?.people, 50)
        XCTAssertEqual(GachaCatalog.item(id: "car")?.people, 100)
        XCTAssertEqual(GachaCatalog.item(id: "train")?.people, 300)
        XCTAssertEqual(GachaCatalog.item(id: "divineHand")?.people, 999)
    }

    /// どの等級を引いても4通りの当たり外れが出るか。
    func testEachRarityHasFourItems() {
        for rarity in GachaRarity.allCases {
            let items = GachaCatalog.items.filter { $0.rarity == rarity }
            XCTAssertEqual(items.count, 4, "\(rarity.label)の種類数が4つではない")
        }
    }

    /// 等級が上がるほど確実に抜ける人数が増えるか。
    func testHigherRarityAlwaysSkipsMorePeople() {
        let ordered = GachaRarity.allCases
        for (lower, higher) in zip(ordered, ordered.dropFirst()) {
            let lowerMax = GachaCatalog.items.filter { $0.rarity == lower }.map(\.people).max() ?? 0
            let higherMin = GachaCatalog.items.filter { $0.rarity == higher }.map(\.people).min() ?? 0
            XCTAssertLessThan(lowerMax, higherMin,
                              "\(lower.label)の最大が\(higher.label)の最小を超えている")
        }
    }

    /// 描き分けを用意した乗り物が、どれも引けずに死蔵されていないか。
    func testEveryVehicleKindIsObtainable() {
        let used = Set(GachaCatalog.items.map(\.vehicle))
        for kind in VehicleKind.allCases {
            XCTAssertTrue(used.contains(kind), "\(kind.rawValue)がどのアイテムにも割り当てられていない")
        }
    }

    /// 画面の中で数えるのではなく、保存した時刻から求めているかどうか。
    func testFreeGachaCooldownComesFromStoredTime() {
        XCTAssertNil(GachaMachine.remainingCooldown(lastDrawnAt: nil, now: noon))
        XCTAssertEqual(
            GachaMachine.remainingCooldown(lastDrawnAt: noon, now: noon.addingTimeInterval(600)) ?? 0,
            3_000,
            accuracy: 1
        )
        XCTAssertNil(GachaMachine.remainingCooldown(lastDrawnAt: noon, now: noon.addingTimeInterval(3_600)))
        XCTAssertNil(
            GachaMachine.remainingCooldown(lastDrawnAt: noon, now: noon.addingTimeInterval(86_400)),
            "閉じている間に何時間経っていても引ける"
        )
    }

    func testCooldownShortensWithEquipment() {
        let shortened = GachaMachine.remainingCooldown(
            lastDrawnAt: noon,
            now: noon,
            multiplier: 0.5
        ) ?? 0
        XCTAssertEqual(shortened, 1_800, accuracy: 1)
    }

    func testCountdownLabelIsMinutesAndSeconds() {
        XCTAssertEqual(GachaMachine.countdownLabel(2_538), "42:18")
        XCTAssertEqual(GachaMachine.countdownLabel(59), "00:59")
    }

    // MARK: - 前進の演出

    /// 抜いた人数によって、演出の強さが段階的に変わること。
    func testSurgeIntensityScalesWithPeople() {
        XCTAssertEqual(Surge.Tier.of(1), .slight)
        XCTAssertEqual(Surge.Tier.of(4), .slight)
        XCTAssertEqual(Surge.Tier.of(5), .moderate)
        XCTAssertEqual(Surge.Tier.of(14), .moderate)
        XCTAssertEqual(Surge.Tier.of(15), .strong)
        XCTAssertEqual(Surge.Tier.of(29), .strong)
        XCTAssertEqual(Surge.Tier.of(30), .massive)
        XCTAssertEqual(Surge.Tier.of(99), .massive)
        XCTAssertEqual(Surge.Tier.of(100), .huge)
        XCTAssertEqual(Surge.Tier.of(299), .huge)
        XCTAssertEqual(Surge.Tier.of(300), .unreal)
        XCTAssertEqual(Surge.Tier.of(2_000), .unreal)
    }

    /// 段階が上がるほど、演出が長く強くなること。
    func testStrongerSurgesLastLongerAndPushHarder() {
        let tiers: [Surge.Tier] = [.slight, .moderate, .strong, .massive, .huge, .unreal]

        for (weaker, stronger) in zip(tiers, tiers.dropFirst()) {
            XCTAssertGreaterThan(stronger.duration, weaker.duration)
            XCTAssertGreaterThanOrEqual(stronger.cameraPush, weaker.cameraPush)
            XCTAssertGreaterThan(stronger.bannerSize, weaker.bannerSize)
        }

        XCTAssertTrue(Surge.Tier.massive.flashes)
        XCTAssertTrue(Surge.Tier.unreal.flashes)
        XCTAssertFalse(Surge.Tier.slight.flashes)
        XCTAssertTrue(Surge.Tier.strong.showsSpeedLines)
        XCTAssertFalse(Surge.Tier.moderate.showsSpeedLines)
    }

    /// テンポを殺さないよう、演出は3秒以内で終わること。
    func testSurgesNeverBlockPlayForTooLong() {
        for people in [1, 5, 20, 100, 300, 5_000] {
            let surge = Surge(
                fromRemaining: 8_000, peopleSkipped: people, startedAt: noon,
                vehicle: nil, vehicleName: nil
            )
            XCTAssertLessThanOrEqual(surge.duration, 3.0, "\(people)人の演出が長すぎる")
        }
    }

    // MARK: - 抽選

    /// 出る割合の合計が100%になること。
    func testLotteryRatesAddUpToOneHundredPercent() {
        let total = Lottery.Result.allCases.reduce(0) { $0 + $1.rate }
        XCTAssertEqual(total, 1.0, accuracy: 0.0001, "抽選の割合の合計が100%になっていない")
    }

    /// 設定した割合どおりに出ること。
    func testLotteryDrawsMatchTheirRates() {
        var counts: [Lottery.Result: Int] = [:]
        let trials = 40_000

        for seed in 0..<trials {
            counts[Lottery.draw(seed: seed).result, default: 0] += 1
        }

        for result in Lottery.Result.allCases {
            let observed = Double(counts[result] ?? 0) / Double(trials)
            XCTAssertEqual(observed, result.rate, accuracy: 0.015,
                           "\(result)の出る割合が設定から離れすぎている")
        }
    }

    /// 上乗せで人数が減ることは絶対にないこと。
    ///
    /// 外れても腕で稼いだぶんは必ずもらえる。そうでないと、
    /// 待たされること自体が罰になって回す気がなくなる。
    func testLotteryNeverTakesAwayWhatWasEarned() {
        for result in Lottery.Result.allCases {
            XCTAssertGreaterThanOrEqual(result.multiplier, 1, "\(result)で人数が減っている")
        }
        XCTAssertEqual(Lottery.Result.miss.multiplier, 1)
    }

    /// 引っぱられたのに外れる回が、ちゃんとあること。
    ///
    /// **煽り＝当たりになってしまうと、煽られる意味がなくなる。**
    /// 揃うまで分からないからこそ、そろった瞬間に価値が出る。
    func testLotterySometimesTeasesAndStillMisses() {
        let trials = 20_000
        var teasedMisses = 0
        var reaches = 0

        for seed in 0..<trials {
            let lottery = Lottery.draw(seed: seed)
            if lottery.showsReach { reaches += 1 }
            if lottery.teases { teasedMisses += 1 }
        }

        XCTAssertGreaterThan(teasedMisses, 0, "煽って外す回が一度もない")

        // 煽られた回のうち、半分以上は外れであってほしい。
        let share = Double(teasedMisses) / Double(reaches)
        XCTAssertGreaterThan(share, 0.4, "煽りがほぼ当たり確定になっている")
    }

    // MARK: - 連続成功の倍率

    /// 連続を積むほど、一度に抜ける人数が跳ね上がること。
    ///
    /// 1000人の行列を19人ずつ削るのは作業なので、
    /// 続けたぶんだけ大きくなる形で爽快感を作っている。
    func testComboTiersRaiseTheMultiplier() {
        XCTAssertEqual(ComboTier.of(0), .none)
        XCTAssertEqual(ComboTier.of(2), .none)
        XCTAssertEqual(ComboTier.of(3), .warm)
        XCTAssertEqual(ComboTier.of(4), .warm)
        XCTAssertEqual(ComboTier.of(5), .hot)
        XCTAssertEqual(ComboTier.of(8), .fever)
        XCTAssertEqual(ComboTier.of(12), .blaze)
        XCTAssertEqual(ComboTier.of(16), .rampage)
        XCTAssertEqual(ComboTier.of(500), .rampage)
    }

    /// 段が上がって倍率が下がることがないこと。
    func testComboMultipliersOnlyGoUp() {
        let tiers = ComboTier.allCases

        for (lower, higher) in zip(tiers, tiers.dropFirst()) {
            XCTAssertGreaterThan(higher.multiplier, lower.multiplier,
                                 "\(higher)の倍率が\(lower)を上回っていない")
            XCTAssertGreaterThan(higher.requiredCombo, lower.requiredCombo)
        }

        XCTAssertNil(ComboTier.none.multiplierLabel, "1倍のときに倍率を出している")
        XCTAssertEqual(ComboTier.rampage.multiplier, 8)
        XCTAssertNil(ComboTier.rampage.next, "最上段の先があることになっている")
    }

    /// 積み上げた見返りが、実際に桁として現れること。
    ///
    /// ステージ7のミッションは19人。連続を積んだときに
    /// それが何人になるのかを、数字で固定しておく。
    func testStreakTurnsASmallRewardIntoABigOne() {
        let reward = 19

        func skipped(afterStreakOf combo: Int) -> Int {
            let tier = ComboTier.of(combo)
            return max(reward, Int((Double(reward) * tier.multiplier).rounded()))
        }

        XCTAssertEqual(skipped(afterStreakOf: 1), 19)
        XCTAssertEqual(skipped(afterStreakOf: 3), 29)
        XCTAssertEqual(skipped(afterStreakOf: 5), 38)
        XCTAssertEqual(skipped(afterStreakOf: 8), 57)
        XCTAssertEqual(skipped(afterStreakOf: 12), 95)
        XCTAssertEqual(skipped(afterStreakOf: 16), 152)

        // 積んだ甲斐が演出にも出ること。
        XCTAssertEqual(Surge.Tier.of(skipped(afterStreakOf: 1)), .strong)
        XCTAssertEqual(Surge.Tier.of(skipped(afterStreakOf: 16)), .huge)
    }

    /// 数字は演出に合わせて減り、途中で戻らないこと。
    func testSurgeCountsDownSmoothlyWithoutGoingBackwards() {
        let surge = Surge(
            fromRemaining: 617, peopleSkipped: 19, startedAt: noon,
            vehicle: nil, vehicleName: nil
        )

        XCTAssertEqual(surge.displayedRemaining(at: noon), 617)
        XCTAssertEqual(surge.displayedRemaining(at: noon.addingTimeInterval(surge.duration)), 598)

        var previous = 618
        for step in stride(from: 0.0, through: surge.duration, by: 0.05) {
            let shown = surge.displayedRemaining(at: noon.addingTimeInterval(step))
            XCTAssertLessThanOrEqual(shown, previous, "数字が増えている")
            previous = shown
        }
    }

    /// 演出が終われば、カメラの寄りも必ず戻ること。
    func testCameraReturnsAfterTheSurge() {
        let surge = Surge(
            fromRemaining: 200, peopleSkipped: 40, startedAt: noon,
            vehicle: nil, vehicleName: nil
        )

        XCTAssertEqual(surge.cameraStrength(at: noon), 0, accuracy: 0.01)
        XCTAssertGreaterThan(surge.cameraStrength(at: noon.addingTimeInterval(surge.duration / 2)), 0.5)
        XCTAssertEqual(surge.cameraStrength(at: noon.addingTimeInterval(surge.duration)), 0, accuracy: 0.01)
        XCTAssertTrue(surge.isFinished(at: noon.addingTimeInterval(surge.duration)))
    }

    /// 乗り物を使ったときは、演出を長めに取ること。
    func testItemSurgesRunLongEnoughToSeeTheVehicle() {
        let onFoot = Surge(
            fromRemaining: 400, peopleSkipped: 100, startedAt: noon,
            vehicle: nil, vehicleName: nil
        )
        let byCar = Surge(
            fromRemaining: 400, peopleSkipped: 100, startedAt: noon,
            vehicle: .car, vehicleName: "車"
        )

        XCTAssertGreaterThan(byCar.duration, onFoot.duration)
        XCTAssertEqual(byCar.countedSoFar(at: noon), 0)
        XCTAssertEqual(byCar.countedSoFar(at: noon.addingTimeInterval(byCar.duration)), 100)

        var previous = 0
        for step in stride(from: 0.0, through: byCar.duration, by: 0.1) {
            let counted = byCar.countedSoFar(at: noon.addingTimeInterval(step))
            XCTAssertGreaterThanOrEqual(counted, previous, "カウンターが戻っている")
            previous = counted
        }
    }

    // MARK: - 保存

    /// 保存した項目を増やしても、古い記録が読めなくなってはいけない。
    func testOldSaveDataStillLoads() throws {
        let legacy = """
        {
          "joinedAt": 760000000,
          "lapStartedAt": 760000000,
          "anchorDate": 760000000,
          "anchorProgress": 7000,
          "lap": 2,
          "totalCutIns": 3,
          "totalSkipped": 0,
          "totalInteractions": 7,
          "nextTicketNumber": 2,
          "collected": []
        }
        """
        let state = try JSONDecoder().decode(QueueState.self, from: Data(legacy.utf8))

        XCTAssertEqual(state.stageNumber, 1)
        XCTAssertEqual(state.anchorProgress, 0, "数える対象が変わったので進捗は引き継がない")
        XCTAssertEqual(state.totalInteractions, 7, "遊んだ記録は残る")
        XCTAssertTrue(state.inventory.isEmpty)
        XCTAssertEqual(state.coins, 0)
        // あとから足した記録も、古いデータから読めなくならないこと。
        XCTAssertEqual(state.bestCombo, 0)
        XCTAssertEqual(state.stagesCleared, 0)
        XCTAssertEqual(state.todaySkipped, 0)
    }

    // MARK: - 人と景品

    func testPeopleAreVariedButStable() {
        let first = PersonFactory.person(atQueueIndex: 431, scene: .shopping)
        let again = PersonFactory.person(atQueueIndex: 431, scene: .shopping)
        XCTAssertEqual(first, again, "同じ人が見るたびに変わってはいけない")

        let descriptors = Set((0..<400).map {
            PersonFactory.person(atQueueIndex: $0, scene: .shopping).descriptor
        })
        XCTAssertGreaterThan(descriptors.count, 60, "並んでいる人が似たり寄ったりで飽きる")
    }

    /// 眺めているだけで飽きないよう、顔ぶれに幅があること。
    func testCrowdHasPlentyOfCharacterTypes() {
        XCTAssertGreaterThanOrEqual(PersonType.allCases.count, 15, "並んでいる人の種類が少ない")

        for type in PersonType.allCases where type != .ordinary {
            XCTAssertFalse(type.label.isEmpty, "\(type)に名前がない")
        }
    }

    /// 新しく足した顔ぶれが、ちゃんと列に出てくること。
    func testNewCharacterTypesActuallyAppear() {
        func types(in scene: SceneKind) -> Set<PersonType> {
            Set((0..<400).map { PersonFactory.person(atQueueIndex: $0, scene: scene).type })
        }

        XCTAssertTrue(types(in: .hall).contains(.cosplayer), "会場にコスプレイヤーがいない")
        XCTAssertTrue(types(in: .residential).contains(.granny), "住宅街におばあちゃんがいない")
        XCTAssertTrue(types(in: .ramen).contains(.foreignTourist), "店の前に観光客がいない")
    }

    /// 吹き出しに、並んでいる最中の呟きが混じっていること。
    func testRemarksIncludeEverydayMutters() {
        let remarks = Set((0..<600).map {
            PersonFactory.person(atQueueIndex: $0, scene: .shopping).remark
        })

        XCTAssertGreaterThan(remarks.count, 20, "吹き出しの種類が少なくて繰り返しに見える")
        XCTAssertTrue(remarks.contains { $0.contains("腹減った") || $0.contains("寒い") },
                      "ただの呟きが入っていない")
    }

    func testCrowdChangesWithTheScenery() {
        func types(in scene: SceneKind) -> Set<PersonType> {
            Set((0..<150).map { PersonFactory.person(atQueueIndex: $0, scene: scene).type })
        }

        XCTAssertTrue(types(in: .space).contains(.alien), "宇宙なのに宇宙人がいない")
        XCTAssertTrue(types(in: .heaven).contains(.angel), "天国なのに天使がいない")
        XCTAssertFalse(types(in: .residential).contains(.angel), "住宅街に天使がうろうろしている")
    }

    func testEveryPrizeIDIsUnique() {
        let ids = Set(PrizeCatalog.all.map(\.id))
        XCTAssertEqual(ids.count, PrizeCatalog.all.count, "景品IDが重複している")
    }
}
