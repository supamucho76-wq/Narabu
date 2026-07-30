import Foundation

/// 行列の進みぐあいを時刻だけから決定的に計算する。
///
/// アプリを閉じている間も列は進むため、進捗は保存せず常に基準時刻から逆算する。
/// 同じ引数には必ず同じ結果を返すので、未来の位置を先読みして通知を予約することもできる。
enum QueueEngine {
    /// 時間帯ごとの1時間あたりの処理人数。
    ///
    /// 昼はおよそ4秒に1人、深夜でも10秒に1人は進む。
    /// 完全に止めてしまうと画面が固まったように見えるので、夜も動かし続ける。
    private static let hourlyRate: [Double] = [
        300, 300, 300, 300, 300, 300,   // 0時-5時
        650, 650, 650,                  // 6時-8時
        1_000, 1_000, 1_000,            // 9時-11時
        700, 700,                       // 12時-13時（窓口も昼休み）
        1_000, 1_000, 1_000, 1_000,     // 14時-17時
        800, 800, 800, 800,             // 18時-21時
        500, 500                        // 22時-23時
    ]

    /// 1時間あたりに割り込みが発生する確率。
    private static let cutInProbability = 0.03

    /// start から end までに窓口が処理した人数。
    static func servedCount(from start: Date, to end: Date) -> Int {
        Int(servedCountExact(from: start, to: end))
    }

    /// 端数を含む処理人数。人の列を滑らかに動かすために使う。
    static func servedCountExact(from start: Date, to end: Date) -> Double {
        guard end > start else { return 0 }

        var total = 0.0
        forEachHour(from: start, to: end) { hourIndex, seconds in
            let rate = hourlyRate[hourOfDay(hourIndex)] * jitter(hourIndex, salt: 0x514E)
            total += rate * seconds / 3600
        }
        return total
    }


    /// start から end までに、課金して割り込んできた人数。
    ///
    /// 完全に経過した時間だけを数えるので、end が進むぶんには結果が減らない。
    static func cutInCount(from start: Date, to end: Date) -> Int {
        guard end > start else { return 0 }

        let firstHour = absoluteHour(start) + 1
        let lastHour = absoluteHour(end)
        guard firstHour <= lastHour else { return 0 }

        var total = 0
        for hour in firstHour...lastHour where unitRandom(hour, salt: 0x9F2C) < cutInProbability {
            total += 1 + Int(unitRandom(hour, salt: 0x33A1) * 4)
        }
        return total
    }

    /// 基準時点から見た、ある時刻での進捗。列の長さに達すると受付に着く。
    ///
    /// 割り込まれるとそのぶん後ろに戻される。
    static func progress(anchorProgress: Int, anchorDate: Date, at date: Date) -> Int {
        let moved = servedCount(from: anchorDate, to: date)
        let pushedBack = cutInCount(from: anchorDate, to: date)
        return min(QueueWorld.length, max(0, anchorProgress + moved - pushedBack))
    }

    /// 受付にたどり着くと予想される時刻。通知の予約に使う。
    static func estimatedArrival(anchorProgress: Int, anchorDate: Date) -> Date {
        // 1時間ずつ粗く進めてから、最後の1時間を1分刻みで詰める。
        var cursor = anchorDate
        while progress(anchorProgress: anchorProgress, anchorDate: anchorDate, at: cursor) < QueueWorld.length {
            cursor = cursor.addingTimeInterval(3_600)
            // 進みが遅すぎて終わらない場合の保険。
            if cursor.timeIntervalSince(anchorDate) > 86_400 * 30 { return cursor }
        }

        var refined = cursor.addingTimeInterval(-3_600)
        while progress(anchorProgress: anchorProgress, anchorDate: anchorDate, at: refined) < QueueWorld.length {
            refined = refined.addingTimeInterval(60)
        }
        return refined
    }

    // MARK: - 内部処理

    /// start-end の区間を1時間ごとに区切り、その時間の通し番号と滞在秒数を渡す。
    private static func forEachHour(from start: Date, to end: Date, body: (Int, Double) -> Void) {
        let startSeconds = start.timeIntervalSince1970
        let endSeconds = end.timeIntervalSince1970

        for hour in absoluteHour(start)...absoluteHour(end) {
            let hourStart = Double(hour) * 3_600
            let from = max(startSeconds, hourStart)
            let to = min(endSeconds, hourStart + 3_600)
            guard to > from else { continue }
            body(hour, to - from)
        }
    }

    private static func absoluteHour(_ date: Date) -> Int {
        Int(floor(date.timeIntervalSince1970 / 3_600))
    }

    private static func hourOfDay(_ absoluteHour: Int) -> Int {
        let offsetHours = TimeZone.current.secondsFromGMT() / 3_600
        return ((absoluteHour + offsetHours) % 24 + 24) % 24
    }

    /// 進みかたを不規則に見せるための、時間ごとに固定された係数。
    private static func jitter(_ value: Int, salt: UInt64) -> Double {
        0.7 + unitRandom(value, salt: salt) * 0.6
    }

    /// 同じ入力には必ず同じ 0..<1 の値を返す。
    static func unitRandom(_ value: Int, salt: UInt64) -> Double {
        var x = UInt64(bitPattern: Int64(value)) &+ salt &* 0x9E37_79B9_7F4A_7C15
        x ^= x >> 30
        x = x &* 0xBF58_476D_1CE4_E5B9
        x ^= x >> 27
        x = x &* 0x94D0_49BB_1331_11EB
        x ^= x >> 31
        return Double(x % 1_000_000) / 1_000_000
    }
}
