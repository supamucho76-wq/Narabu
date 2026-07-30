import Foundation
import UserNotifications

/// 列が進んだことを知らせる通知。
///
/// バックグラウンドでは計算できないので、進みかたを先読みして通知を予約しておく。
enum NotificationScheduler {
    private static let maxScheduled = 20
    /// 通知の間隔。短すぎると煩わしく、長すぎると忘れられる。
    private static let intervalMinutes = 30.0

    static func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// 予約済みの通知をすべて捨てて、今の状態から組み直す。
    static func reschedule(
        anchorProgress: Int,
        anchorDate: Date,
        queueLength: Int,
        stageName: String,
        from now: Date = .now
    ) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        guard await isAuthorized(center) else { return }

        var previous = QueueEngine.progress(
            anchorProgress: anchorProgress,
            anchorDate: anchorDate,
            at: now,
            limit: queueLength
        )

        for step in 1...maxScheduled {
            let fireDate = now.addingTimeInterval(intervalMinutes * 60 * Double(step))
            let current = QueueEngine.progress(
                anchorProgress: anchorProgress,
                anchorDate: anchorDate,
                at: fireDate,
                limit: queueLength
            )
            defer { previous = current }

            guard let content = content(
                from: previous,
                to: current,
                queueLength: queueLength,
                stageName: stageName
            ) else { continue }

            let request = UNNotificationRequest(
                identifier: "queue-\(step)",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(
                    timeInterval: fireDate.timeIntervalSince(now),
                    repeats: false
                )
            )
            try? await center.add(request)

            // 先頭に着いたらそれ以上は知らせることがない。
            if current >= queueLength { break }
        }
    }

    private static func content(
        from previous: Int,
        to current: Int,
        queueLength: Int,
        stageName: String
    ) -> UNMutableNotificationContent? {
        let content = UNMutableNotificationContent()
        content.sound = .default

        if current >= queueLength {
            content.title = "先頭に着きました"
            content.body = "\(stageName)をクリアできます。"
        } else if current < previous {
            content.title = "追い抜かれました"
            content.body = "\(previous - current)人に割り込まれました。"
        } else if current > previous {
            content.title = "列が進みました"
            content.body = "\(stageName)、あと\((queueLength - current).formatted())人です。"
        } else {
            return nil
        }
        return content
    }

    private static func isAuthorized(_ center: UNUserNotificationCenter) async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
    }
}
