import Testing
import Foundation
@testable import Narabu

struct QueueEngineTests {
    private let noon = Date(timeIntervalSince1970: 1_760_000_000)

    @Test func 同じ区間なら何度計算しても同じ結果になる() {
        let later = noon.addingTimeInterval(86_400 * 3)
        #expect(
            QueueEngine.servedCount(from: noon, to: later)
                == QueueEngine.servedCount(from: noon, to: later)
        )
    }

    @Test func 時間が経つほど列は進む() {
        let oneDay = QueueEngine.servedCount(from: noon, to: noon.addingTimeInterval(86_400))
        let twoDays = QueueEngine.servedCount(from: noon, to: noon.addingTimeInterval(86_400 * 2))
        #expect(oneDay > 0)
        #expect(twoDays > oneDay)
    }

    @Test func 過去にさかのぼっても列は戻らない() {
        #expect(QueueEngine.servedCount(from: noon, to: noon.addingTimeInterval(-3_600)) == 0)
        #expect(QueueEngine.cutInCount(from: noon, to: noon.addingTimeInterval(-3_600)) == 0)
    }

    @Test func 割り込み人数は時間が進んでも減らない() {
        var previous = 0
        for hours in stride(from: 0, through: 24 * 14, by: 6) {
            let count = QueueEngine.cutInCount(
                from: noon,
                to: noon.addingTimeInterval(Double(hours) * 3_600)
            )
            #expect(count >= previous)
            previous = count
        }
    }

    @Test func 並び順は先頭で止まりマイナスにならない() {
        let position = QueueEngine.position(
            anchorPosition: 100,
            anchorDate: noon,
            at: noon.addingTimeInterval(86_400 * 60)
        )
        #expect(position == 0)
    }

    @Test func 二週間ほどで先頭にたどり着く() {
        let start = QueueEngine.newTailPosition(seed: 42)
        #expect(start >= 7_000)
        #expect(start <= 9_500)

        let arrival = QueueEngine.estimatedArrival(anchorPosition: start, anchorDate: noon)
        let days = arrival.timeIntervalSince(noon) / 86_400
        #expect(days > 10)
        #expect(days < 35)
    }

    @Test func 景色は先頭に近づくほど暗くなる() {
        let far = QueueScenery.current(for: 8_000)
        let near = QueueScenery.current(for: 10)
        #expect(far.skyTone > near.skyTone)
        #expect(near.isSheltered)
        #expect(!far.isSheltered)
    }

    @Test func 周回ごとの景品は引き直せない() {
        let joined = noon
        let first = PrizeCatalog.prize(forLap: 3, joinedAt: joined)
        let again = PrizeCatalog.prize(forLap: 3, joinedAt: joined)
        #expect(first == again)
    }
}
