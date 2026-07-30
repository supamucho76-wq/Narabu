import Foundation

/// ガチャの抽選。
enum GachaMachine {
    /// 排出率にしたがって1回引く。
    ///
    /// - Parameter luck: 装備やスキルによる補正。大きいほど高レアの重みが増える。
    static func draw(luck: Double = 0, using generator: inout some RandomNumberGenerator) -> GachaItem {
        let weights = GachaCatalog.items.map { weight(for: $0, luck: luck) }
        let total = weights.reduce(0, +)
        var roll = Double.random(in: 0..<total, using: &generator)

        for (item, weight) in zip(GachaCatalog.items, weights) {
            roll -= weight
            if roll < 0 { return item }
        }
        return GachaCatalog.items[0]
    }

    /// 運が良いほど、レアなものほど重みが増える。
    private static func weight(for item: GachaItem, luck: Double) -> Double {
        item.dropRate * (1 + luck * item.rarity.glowStrength)
    }

    static func draw(luck: Double = 0) -> GachaItem {
        var generator = SystemRandomNumberGenerator()
        return draw(luck: luck, using: &generator)
    }

    static func draw(count: Int, luck: Double = 0) -> [GachaItem] {
        (0..<count).map { _ in draw(luck: luck) }
    }

    /// 次の無料ガチャが引けるようになる時刻。一度も引いていなければ今すぐ引ける。
    static func nextFreeGachaDate(after lastDrawnAt: Date?, multiplier: Double = 1) -> Date? {
        guard let lastDrawnAt else { return nil }
        return lastDrawnAt.addingTimeInterval(GachaCatalog.freeGachaInterval * multiplier)
    }

    /// 残り時間。引ける状態なら nil。
    ///
    /// 画面の中でカウントするのではなく、保存した時刻と今の時刻を突き合わせて求めるので、
    /// アプリを閉じていた間も時間は進む。
    static func remainingCooldown(
        lastDrawnAt: Date?,
        now: Date,
        multiplier: Double = 1
    ) -> TimeInterval? {
        guard let next = nextFreeGachaDate(after: lastDrawnAt, multiplier: multiplier) else { return nil }
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
