import Foundation
import Observation

/// 並んでいる状態のすべてを保持する。
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

    // MARK: - 現在の状況

    /// 最後尾から何人ぶん進んだか。列の長さに達すると受付。
    var progress: Int {
        QueueEngine.progress(
            anchorProgress: state.anchorProgress,
            anchorDate: state.anchorDate,
            at: now
        )
    }

    /// 受付までの残り人数。
    var remaining: Int { QueueWorld.length - progress }

    var hasReachedReception: Bool { remaining <= 0 }

    var stage: WorldStage { QueueWorld.stage(at: progress) }

    var peopleUntilNextStage: Int? { QueueWorld.peopleUntilNextStage(at: progress) }

    /// 次にたどり着く場所の名前。
    var nextStageName: String? {
        let index = QueueWorld.stageIndex(at: progress)
        guard index + 1 < QueueWorld.stages.count else { return nil }
        return QueueWorld.stages[index + 1].name
    }

    /// 屋根の下に入ると、天気は関係なくなる。
    var weather: QueueWeather { QueueWeather.onDay(of: now) }

    /// すぐ前に並んでいる人。
    var personAhead: QueuePerson {
        PersonFactory.person(atQueueIndex: max(0, remaining - 1))
    }

    /// これまでに割り込まれた合計人数。基準時刻をまたいでも積み上がる。
    var totalCutIns: Int {
        state.totalCutIns + QueueEngine.cutInCount(from: state.anchorDate, to: now)
    }

    /// 今の周回で並んでいる時間。
    var hoursInCurrentLap: Int {
        max(0, Int(now.timeIntervalSince(state.lapStartedAt) / 3_600))
    }

    /// この周回で受け取ることになっている景品。受付に着くまでは見せない。
    var pendingPrize: Prize {
        PrizeCatalog.prize(forLap: state.lap, joinedAt: state.joinedAt)
    }

    // MARK: - 操作

    /// 受付で景品を受け取り、最後尾に並び直す。
    @discardableResult
    func claimPrize() -> CollectedPrize? {
        guard hasReachedReception else { return nil }

        let prize = pendingPrize
        let record = CollectedPrize(
            id: UUID(),
            prizeID: prize.id,
            receivedAt: now,
            ticketNumber: state.nextTicketNumber,
            lap: state.lap,
            hoursWaited: hoursInCurrentLap,
            weather: weather
        )

        state.collected.append(record)
        state.nextTicketNumber += 1
        state.lap += 1
        state.lapStartedAt = now
        moveAnchor(to: 0)
        save()

        return record
    }

    /// 前の人に何かする。ごくまれに相手が列を抜けて、1人ぶん進む。
    func interactWithPersonAhead(_ action: QueueAction) -> ActionOutcome {
        guard !hasReachedReception else {
            return ActionOutcome(message: "受付の人に絡むのはやめておいた。", didAdvance: false)
        }

        state.totalInteractions += 1
        let outcome = QueueActions.outcome(
            action: action,
            totalInteractions: state.totalInteractions,
            seed: state.totalInteractions &* 31 &+ remaining
        )

        if outcome.didAdvance {
            moveAnchor(to: min(QueueWorld.length, progress + 1))
        }
        save()

        return outcome
    }

    /// 課金して前の人を追い抜く。
    func skipAhead(by people: Int) {
        state.totalSkipped += people
        moveAnchor(to: min(QueueWorld.length, progress + people))
        save()
    }

    /// 列を抜けて、最後尾からやり直す。
    func leaveQueue() {
        state.lapStartedAt = now
        moveAnchor(to: 0)
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
