import Foundation

/// ガチャの抽選。
enum GachaMachine {
    /// 排出率にしたがって1回引く。
    static func draw(using generator: inout some RandomNumberGenerator) -> GachaItem {
        let total = GachaCatalog.items.reduce(0) { $0 + $1.dropRate }
        var roll = Double.random(in: 0..<total, using: &generator)

        for item in GachaCatalog.items {
            roll -= item.dropRate
            if roll < 0 { return item }
        }
        return GachaCatalog.items[0]
    }

    static func draw() -> GachaItem {
        var generator = SystemRandomNumberGenerator()
        return draw(using: &generator)
    }

    static func draw(count: Int) -> [GachaItem] {
        (0..<count).map { _ in draw() }
    }

    /// 次の無料ガチャが引けるようになる時刻。一度も引いていなければ今すぐ引ける。
    static func nextFreeGachaDate(after lastDrawnAt: Date?) -> Date? {
        guard let lastDrawnAt else { return nil }
        return lastDrawnAt.addingTimeInterval(GachaCatalog.freeGachaInterval)
    }

    /// 残り時間。引ける状態なら nil。
    ///
    /// 画面の中でカウントするのではなく、保存した時刻と今の時刻を突き合わせて求めるので、
    /// アプリを閉じていた間も時間は進む。
    static func remainingCooldown(lastDrawnAt: Date?, now: Date) -> TimeInterval? {
        guard let next = nextFreeGachaDate(after: lastDrawnAt) else { return nil }
        let remaining = next.timeIntervalSince(now)
        return remaining > 0 ? remaining : nil
    }

    /// 「42:18」の形にする。
    static func countdownLabel(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded(.up))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
