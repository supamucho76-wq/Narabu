import Foundation
import Observation

/// 並んでいる状態のすべてを保持する。
///
/// 位置そのものは保存せず、基準時刻からの経過で毎回計算する。
/// アプリを消していた間も列は進んでいる。
@MainActor
@Observable
final class QueueStore {
    private(set) var state: QueueState
    /// 表示を更新するための現在時刻。1秒ごとに進む。
    private(set) var now: Date = .now

    private let fileURL: URL
    private var ticker: Task<Void, Never>?

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        state = Self.load(from: self.fileURL) ?? .initial()
        save()
    }

    // MARK: - 現在の状況

    /// 並び順。0 は先頭で、景品を受け取れる状態。
    var position: Int {
        QueueEngine.position(
            anchorPosition: state.anchorPosition,
            anchorDate: state.anchorDate,
            at: now
        )
    }

    var hasReachedFront: Bool { position == 0 }

    var scenery: QueueScenery { QueueScenery.current(for: position) }

    var peopleUntilNextScenery: Int? { QueueScenery.peopleUntilNextStage(from: position) }

    /// 屋根の下に入ると、天気は景色に影響しなくなる。
    var weather: QueueWeather { QueueWeather.onDay(of: now) }

    var personAhead: Neighbor {
        NeighborGenerator.neighbor(at: position, offset: -1, lap: state.lap)
    }

    var personBehind: Neighbor {
        NeighborGenerator.neighbor(at: position, offset: 1, lap: state.lap)
    }

    /// これまでに割り込まれた合計人数。基準時刻をまたいでも積み上がる。
    var totalCutIns: Int {
        state.totalCutIns + QueueEngine.cutInCount(from: state.anchorDate, to: now)
    }

    /// 今の周回で並んでいる日数。
    var daysInCurrentLap: Int {
        max(0, Calendar.current.dateComponents([.day], from: state.lapStartedAt, to: now).day ?? 0)
    }

    /// この周回で受け取ることになっている景品。先頭に着くまでは見せない。
    var pendingPrize: Prize {
        PrizeCatalog.prize(forLap: state.lap, joinedAt: state.joinedAt)
    }

    // MARK: - 操作

    /// 先頭で景品を受け取り、最後尾に並び直す。
    @discardableResult
    func claimPrize() -> CollectedPrize? {
        guard hasReachedFront else { return nil }

        let prize = pendingPrize
        let record = CollectedPrize(
            id: UUID(),
            prizeID: prize.id,
            receivedAt: now,
            ticketNumber: state.nextTicketNumber,
            lap: state.lap,
            daysWaited: daysInCurrentLap,
            weather: weather
        )

        state.collected.append(record)
        state.nextTicketNumber += 1
        state.lap += 1
        state.lapStartedAt = now
        moveAnchor(to: QueueEngine.newTailPosition(seed: Int(now.timeIntervalSince1970)))
        save()

        return record
    }

    /// 課金して前の人を追い抜く。
    func skipAhead(by people: Int) {
        let destination = max(0, position - people)
        state.totalSkipped += people
        moveAnchor(to: destination)
        save()
    }

    /// 列を抜けて、最後尾からやり直す。
    func leaveQueue() {
        state.lapStartedAt = now
        moveAnchor(to: QueueEngine.newTailPosition(seed: Int(now.timeIntervalSince1970)))
        save()
    }

    /// 基準を今に張り直す。割り込まれた人数は先に確定させてから移す。
    private func moveAnchor(to newPosition: Int) {
        state.totalCutIns = totalCutIns
        state.anchorDate = now
        state.anchorPosition = newPosition
    }

    // MARK: - 時刻の更新

    func startTicking() {
        guard ticker == nil else { return }
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                await MainActor.run { self?.refresh() }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func stopTicking() {
        ticker?.cancel()
        ticker = nil
    }

    /// 表示に使う現在時刻を進める。位置も割り込みもここから再計算される。
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
            // 保存できなくても列に並び続けられるほうが大事なので、握りつぶす。
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
