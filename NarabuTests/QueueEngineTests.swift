import XCTest
@testable import Narabu

final class QueueEngineTests: XCTestCase {
    private let noon = Date(timeIntervalSince1970: 1_760_000_000)

    func testSameIntervalAlwaysProducesSameResult() {
        let later = noon.addingTimeInterval(86_400 * 3)
        XCTAssertEqual(
            QueueEngine.servedCount(from: noon, to: later),
            QueueEngine.servedCount(from: noon, to: later),
            "同じ区間を何度計算しても結果が変わってはいけない"
        )
    }

    func testQueueAdvancesAsTimePasses() {
        let oneDay = QueueEngine.servedCount(from: noon, to: noon.addingTimeInterval(86_400))
        let twoDays = QueueEngine.servedCount(from: noon, to: noon.addingTimeInterval(86_400 * 2))
        XCTAssertGreaterThan(oneDay, 0)
        XCTAssertGreaterThan(twoDays, oneDay)
    }

    func testQueueNeverMovesBackwardForPastDates() {
        XCTAssertEqual(QueueEngine.servedCount(from: noon, to: noon.addingTimeInterval(-3_600)), 0)
        XCTAssertEqual(QueueEngine.cutInCount(from: noon, to: noon.addingTimeInterval(-3_600)), 0)
    }

    func testCutInCountNeverDecreases() {
        var previous = 0
        for hours in stride(from: 0, through: 24 * 14, by: 6) {
            let count = QueueEngine.cutInCount(
                from: noon,
                to: noon.addingTimeInterval(Double(hours) * 3_600)
            )
            XCTAssertGreaterThanOrEqual(count, previous, "\(hours)時間後に割り込み数が減っている")
            previous = count
        }
    }

    func testPositionStopsAtFrontAndNeverGoesNegative() {
        let position = QueueEngine.position(
            anchorPosition: 100,
            anchorDate: noon,
            at: noon.addingTimeInterval(86_400 * 60)
        )
        XCTAssertEqual(position, 0)
    }

    func testReachesFrontInRoughlyTwoWeeks() {
        let start = QueueEngine.newTailPosition(seed: 42)
        XCTAssertGreaterThanOrEqual(start, 200_000)
        XCTAssertLessThanOrEqual(start, 260_000)

        let arrival = QueueEngine.estimatedArrival(anchorPosition: start, anchorDate: noon)
        let days = arrival.timeIntervalSince(noon) / 86_400
        XCTAssertGreaterThan(days, 8, "早すぎると並んだ実感がない")
        XCTAssertLessThan(days, 28, "遅すぎると忘れられる")
    }

    /// 画面を見ているあいだも数字が動いていないと、止まって見えてしまう。
    func testQueueAdvancesAboutOncePerFiveSeconds() {
        let perHour = QueueEngine.servedCountExact(from: noon, to: noon.addingTimeInterval(3_600))
        let secondsPerPerson = 3_600 / perHour
        XCTAssertGreaterThan(secondsPerPerson, 2)
        XCTAssertLessThan(secondsPerPerson, 12)
    }

    func testAdvanceFractionStaysBetweenZeroAndOne() {
        for seconds in stride(from: 0, through: 600, by: 7) {
            let fraction = QueueEngine.advanceFraction(
                anchorDate: noon,
                at: noon.addingTimeInterval(Double(seconds))
            )
            XCTAssertGreaterThanOrEqual(fraction, 0)
            XCTAssertLessThan(fraction, 1)
        }
    }

    func testSceneryGetsDarkerCloserToTheFront() {
        let far = QueueScenery.current(for: 230_000)
        let near = QueueScenery.current(for: 10)
        XCTAssertGreaterThan(far.skyTone, near.skyTone)
        XCTAssertTrue(near.isSheltered)
        XCTAssertFalse(far.isSheltered)
    }

    func testSceneryCoversEveryPositionDownToZero() {
        for position in [0, 1, 399, 400, 2_999, 12_000, 34_999, 180_000, 999_999] {
            XCTAssertNotNil(QueueScenery.stages.first { position >= $0.fromPosition })
        }
    }

    func testTappingSometimesMakesThePersonAheadLeave() {
        let departures = (0..<2_000).filter { seed in
            TapReactions.outcome(totalTaps: seed, seed: seed).didAdvance
        }.count
        XCTAssertGreaterThan(departures, 0, "まったく列を抜けないと叩く意味がない")
        XCTAssertLessThan(departures, 200, "簡単に抜けすぎると並ぶ意味がなくなる")
    }

    func testTapReactionsGetColderAsTapsPileUp() {
        let differing = (0..<200).filter { seed in
            TapReactions.outcome(totalTaps: 1, seed: seed).message
                != TapReactions.outcome(totalTaps: 500, seed: seed).message
        }.count
        XCTAssertGreaterThan(differing, 150, "叩いた回数で反応が変わっていない")
    }

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
