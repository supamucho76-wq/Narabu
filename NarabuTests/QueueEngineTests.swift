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

    /// 画面を見ているあいだも列が動いていないと、止まって見えてしまう。
    func testQueueAdvancesAboutOncePerFiveSeconds() {
        let perHour = QueueEngine.servedCountExact(from: noon, to: noon.addingTimeInterval(3_600))
        let secondsPerPerson = 3_600 / perHour
        XCTAssertGreaterThan(secondsPerPerson, 2)
        XCTAssertLessThan(secondsPerPerson, 12)
    }

    // MARK: - 進捗

    func testProgressStopsAtTheReception() {
        let progress = QueueEngine.progress(
            anchorProgress: 0,
            anchorDate: noon,
            at: noon.addingTimeInterval(86_400 * 7)
        )
        XCTAssertEqual(progress, QueueWorld.length)
    }

    func testProgressNeverGoesNegative() {
        let progress = QueueEngine.progress(
            anchorProgress: 0,
            anchorDate: noon,
            at: noon
        )
        XCTAssertGreaterThanOrEqual(progress, 0)
    }

    func testReachesReceptionWithinADay() {
        let arrival = QueueEngine.estimatedArrival(anchorProgress: 0, anchorDate: noon)
        let hours = arrival.timeIntervalSince(noon) / 3_600
        XCTAssertGreaterThan(hours, 6, "早すぎると並んだ実感がない")
        XCTAssertLessThan(hours, 30, "遅すぎると忘れられる")
    }

    // MARK: - 世界

    func testEveryStageIsReachableAndOrdered() {
        var previous = 0
        for stage in QueueWorld.stages where stage.untilProgress != .max {
            XCTAssertGreaterThan(stage.untilProgress, previous, "場所の順番が逆転している")
            previous = stage.untilProgress
        }
        XCTAssertEqual(previous, QueueWorld.length, "最後の場所が受付につながっていない")
    }

    func testStageMatchesTheSpecifiedRanges() {
        XCTAssertEqual(QueueWorld.stage(at: 0).kind, .residential)
        XCTAssertEqual(QueueWorld.stage(at: 999).kind, .residential)
        XCTAssertEqual(QueueWorld.stage(at: 1_000).kind, .shopping)
        XCTAssertEqual(QueueWorld.stage(at: 2_000).kind, .forest)
        XCTAssertEqual(QueueWorld.stage(at: 3_000).kind, .sea)
        XCTAssertEqual(QueueWorld.stage(at: 4_000).kind, .snow)
        XCTAssertEqual(QueueWorld.stage(at: 5_000).kind, .desert)
        XCTAssertEqual(QueueWorld.stage(at: 6_000).kind, .space)
        XCTAssertEqual(QueueWorld.stage(at: 7_000).kind, .hell)
        XCTAssertEqual(QueueWorld.stage(at: 7_600).kind, .heaven)
        XCTAssertEqual(QueueWorld.stage(at: 8_000).kind, .ramen)
    }

    /// 場所ごとに並んでいる顔ぶれが変わらないと、景色が変わった実感が出ない。
    func testCrowdChangesWithTheScenery() {
        func types(around progress: Int) -> Set<PersonType> {
            let index = QueueWorld.length - progress
            return Set((0..<120).map { PersonFactory.person(atQueueIndex: index + $0).type })
        }

        XCTAssertTrue(types(around: 6_500).contains(.alien), "宇宙なのに宇宙人がいない")
        XCTAssertTrue(types(around: 7_800).contains(.angel), "天国なのに天使がいない")
        XCTAssertFalse(types(around: 500).contains(.angel), "住宅街に天使がうろうろしている")
    }

    func testEntryBlendRisesAfterEnteringAStage() {
        XCTAssertEqual(QueueWorld.entryBlend(at: 1_000), 0, accuracy: 0.001)
        XCTAssertEqual(QueueWorld.entryBlend(at: 1_250), 1, accuracy: 0.001)
        XCTAssertGreaterThan(QueueWorld.entryBlend(at: 1_125), 0.4)
    }

    // MARK: - 人

    func testPeopleAreVariedButStable() {
        let first = PersonFactory.person(atQueueIndex: 4_321)
        let again = PersonFactory.person(atQueueIndex: 4_321)
        XCTAssertEqual(first, again, "同じ人が見るたびに変わってはいけない")

        let descriptors = Set((0..<400).map { PersonFactory.person(atQueueIndex: $0).descriptor })
        XCTAssertGreaterThan(descriptors.count, 60, "並んでいる人が似たり寄ったりで飽きる")
    }

    // MARK: - アクション

    func testInteractionsSometimesMakeThePersonAheadLeave() {
        let departures = (0..<2_000).filter { seed in
            QueueActions.outcome(action: .tapShoulder, totalInteractions: seed, seed: seed).didAdvance
        }.count
        XCTAssertGreaterThan(departures, 0, "まったく列を抜けないと絡む意味がない")
        XCTAssertLessThan(departures, 200, "簡単に抜けすぎると並ぶ意味がなくなる")
    }

    func testEachActionHasItsOwnReactions() {
        for action in QueueAction.allCases {
            let messages = Set((0..<60).map {
                QueueActions.outcome(action: action, totalInteractions: 1, seed: $0).message
            })
            XCTAssertGreaterThan(messages.count, 2, "\(action.label)の反応が単調すぎる")
        }
    }

    // MARK: - ガチャ

    func testDropRatesAddUpToOneHundredPercent() {
        let total = GachaCatalog.items.reduce(0) { $0 + $1.dropRate }
        XCTAssertEqual(total, 1.0, accuracy: 0.0001, "排出率の合計が100%になっていない")
    }

    func testEveryItemIsReachableAndRoughlyMatchesItsRate() {
        var counts: [String: Int] = [:]
        var generator = SeededGenerator(seed: 20_260_730)

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
        let drawnAt = noon
        XCTAssertNil(
            GachaMachine.remainingCooldown(lastDrawnAt: nil, now: noon),
            "一度も引いていないなら引ける"
        )
        XCTAssertEqual(
            GachaMachine.remainingCooldown(lastDrawnAt: drawnAt, now: noon.addingTimeInterval(600)) ?? 0,
            3_000,
            accuracy: 1
        )
        XCTAssertNil(
            GachaMachine.remainingCooldown(lastDrawnAt: drawnAt, now: noon.addingTimeInterval(3_600)),
            "1時間経ったら引ける"
        )
        XCTAssertNil(
            GachaMachine.remainingCooldown(lastDrawnAt: drawnAt, now: noon.addingTimeInterval(86_400)),
            "閉じている間に何時間経っていても引ける"
        )
    }

    func testCountdownLabelIsMinutesAndSeconds() {
        XCTAssertEqual(GachaMachine.countdownLabel(2_538), "42:18")
        XCTAssertEqual(GachaMachine.countdownLabel(59), "00:59")
    }

    // MARK: - ごぼう抜き

    func testOvertakeCounterRisesFromZeroToTheSkippedCount() {
        let run = OvertakeRun(
            item: GachaCatalog.item(id: "car")!,
            fromRemaining: 4_000,
            peopleSkipped: 100,
            startedAt: noon
        )

        XCTAssertEqual(run.countedSoFar(at: noon), 0)
        XCTAssertEqual(run.countedSoFar(at: noon.addingTimeInterval(run.duration)), 100)
        XCTAssertEqual(run.displayedRemaining(at: noon), 4_000)
        XCTAssertEqual(run.displayedRemaining(at: noon.addingTimeInterval(run.duration)), 3_900)

        var previous = 0
        for step in stride(from: 0.0, through: run.duration, by: 0.1) {
            let counted = run.countedSoFar(at: noon.addingTimeInterval(step))
            XCTAssertGreaterThanOrEqual(counted, previous, "カウンターが戻っている")
            previous = counted
        }
    }

    /// 保存した項目を増やしても、古い記録が読めなくなってはいけない。
    func testOldSaveDataStillLoads() throws {
        let legacy = """
        {
          "joinedAt": 760000000,
          "lapStartedAt": 760000000,
          "anchorDate": 760000000,
          "anchorProgress": 1234,
          "lap": 2,
          "totalCutIns": 3,
          "totalSkipped": 0,
          "totalInteractions": 7,
          "nextTicketNumber": 2,
          "collected": []
        }
        """
        let state = try JSONDecoder().decode(QueueState.self, from: Data(legacy.utf8))

        XCTAssertEqual(state.anchorProgress, 1_234)
        XCTAssertEqual(state.lap, 2)
        XCTAssertTrue(state.inventory.isEmpty)
        XCTAssertFalse(state.hasDrawnStarterGacha)
        XCTAssertNil(state.lastFreeGachaAt)
    }

    // MARK: - 景品

    func testPrizeForLapCannotBeRerolled() {
        let first = PrizeCatalog.prize(forLap: 3, joinedAt: noon)
        let again = PrizeCatalog.prize(forLap: 3, joinedAt: noon)
        XCTAssertEqual(first, again)
    }

    func testEveryPrizeIDIsUnique() {
        let ids = Set(PrizeCatalog.all.map(\.id))
        XCTAssertEqual(ids.count, PrizeCatalog.all.count, "景品IDが重複している")
    }
}
