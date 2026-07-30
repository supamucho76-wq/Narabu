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

    /// イントロと初回ガチャで数分かかっても、ステージ1が勝手に終わらないこと。
    func testFirstStageSurvivesTheOpeningSequence() {
        let openingMinutes = 5.0
        let progress = QueueEngine.progress(
            anchorProgress: 0,
            anchorDate: noon,
            at: noon.addingTimeInterval(openingMinutes * 60),
            limit: StageCatalog.stages[0].queueLength
        )
        XCTAssertLessThan(progress, StageCatalog.stages[0].queueLength,
                          "開始前の数分でステージ1がクリアされてしまう")
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

    /// 相手に合った手を選べば進み、間違えれば下がる。当てずっぽうでは進めない。
    func testActionResultDependsOnThePersonAhead() {
        let sleepy = PersonFactory.person(atQueueIndex: 7, scene: .shopping)
        let personality = sleepy.personality

        let best = QueueActions.outcome(
            action: personality.best,
            person: sleepy,
            repeatCount: 0,
            seed: 1
        )
        XCTAssertGreaterThan(best.advance, 0, "最適な手なのに進めない")

        let worst = QueueActions.outcome(
            action: personality.worst,
            person: sleepy,
            repeatCount: 0,
            seed: 1
        )
        XCTAssertLessThan(worst.advance, 0, "やってはいけない手なのに罰がない")
    }

    /// 同じボタンを連打するだけで最適解にならないこと。
    func testRepeatingTheSameActionStopsWorking() {
        let person = PersonFactory.person(atQueueIndex: 12, scene: .forest)
        let action = person.personality.best

        let fresh = (0..<200).filter { seed in
            QueueActions.outcome(action: action, person: person, repeatCount: 0, seed: seed).advance > 0
        }.count
        let tired = (0..<200).filter { seed in
            QueueActions.outcome(action: action, person: person, repeatCount: 4, seed: seed).advance > 0
        }.count

        XCTAssertGreaterThan(fresh, tired, "連打しても成功率が落ちていない")
    }

    func testEveryPersonalityHasADistinctBestAndWorstAction() {
        for personality in Personality.allCases {
            XCTAssertNotEqual(personality.best, personality.worst,
                              "\(personality.label)の最適解と地雷が同じ")
            XCTAssertFalse(personality.hint.isEmpty, "\(personality.label)に手がかりがない")
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

    func testAllMissionKindsCanAppear() {
        var seenMash = false
        var seenTiming = false
        var seenQuiz = false
        var seenMemory = false
        var seenSequence = false

        for seed in 0..<300 {
            switch MissionFactory.make(seed: seed, stage: StageCatalog.stages[3]).kind {
            case .mash: seenMash = true
            case .timing: seenTiming = true
            case .quiz: seenQuiz = true
            case .memory: seenMemory = true
            case .sequence: seenSequence = true
            }
        }

        XCTAssertTrue(seenMash && seenTiming && seenQuiz && seenMemory && seenSequence,
                      "出てこないミッションの種類がある")
    }

    func testQuizAnswersPointToRealChoices() {
        for seed in 0..<300 {
            let mission = MissionFactory.make(seed: seed, stage: StageCatalog.stages[0])
            if case .quiz(_, let choices, let answer, _) = mission.kind {
                XCTAssertTrue(choices.indices.contains(answer), "正解の番号が選択肢の外にある")
            }
            if case .memory(_, let choices, let answer) = mission.kind {
                XCTAssertTrue(choices.indices.contains(answer), "正解の番号が選択肢の外にある")
            }
        }
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

    func testCatalogHasTheFiveExpectedItems() {
        XCTAssertEqual(GachaCatalog.items.count, 5)
        XCTAssertEqual(GachaCatalog.item(id: "dash")?.people, 5)
        XCTAssertEqual(GachaCatalog.item(id: "bicycle")?.people, 20)
        XCTAssertEqual(GachaCatalog.item(id: "motorbike")?.people, 50)
        XCTAssertEqual(GachaCatalog.item(id: "car")?.people, 100)
        XCTAssertEqual(GachaCatalog.item(id: "train")?.people, 300)
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

    // MARK: - ごぼう抜き

    func testOvertakeCounterRisesFromZeroToTheSkippedCount() {
        let run = OvertakeRun(
            item: GachaCatalog.item(id: "car")!,
            fromRemaining: 400,
            peopleSkipped: 100,
            startedAt: noon
        )

        XCTAssertEqual(run.countedSoFar(at: noon), 0)
        XCTAssertEqual(run.countedSoFar(at: noon.addingTimeInterval(run.duration)), 100)
        XCTAssertEqual(run.displayedRemaining(at: noon.addingTimeInterval(run.duration)), 300)

        var previous = 0
        for step in stride(from: 0.0, through: run.duration, by: 0.1) {
            let counted = run.countedSoFar(at: noon.addingTimeInterval(step))
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
