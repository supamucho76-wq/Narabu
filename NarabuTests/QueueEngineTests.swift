import XCTest
@testable import Narabu

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
        XCTAssertEqual(QueueWorld.stage(at: 3_000).kind, .forest)
        XCTAssertEqual(QueueWorld.stage(at: 5_000).kind, .snow)
        XCTAssertEqual(QueueWorld.stage(at: 7_000).kind, .hotel)
        XCTAssertEqual(QueueWorld.stage(at: 7_900).kind, .palace)
        XCTAssertEqual(QueueWorld.stage(at: 8_000).kind, .reception)
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
