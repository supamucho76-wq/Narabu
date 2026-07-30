import Foundation
import UserNotifications

/// 列が進んだことを知らせる通知。
///
/// バックグラウンドでは計算できないので、進みかたを先読みして通知を予約しておく。
/// 何の列かわからないまま「列が3人進みました」とだけ届くのが狙い。
enum NotificationScheduler {
    private static let maxScheduled = 24
    /// 通知の間隔。短すぎると煩わしく、長すぎると忘れられる。
    private static let intervalHours = 8.0

    static func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// 予約済みの通知をすべて捨てて、今の状態から組み直す。
    /// 列を進めたり並び直したりしたあとに呼ぶ。
    static func reschedule(anchorPosition: Int, anchorDate: Date, from now: Date = .now) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        guard await isAuthorized(center) else { return }

        var previous = QueueEngine.position(
            anchorPosition: anchorPosition,
            anchorDate: anchorDate,
            at: now
        )

        for step in 1...maxScheduled {
            let fireDate = now.addingTimeInterval(intervalHours * 3_600 * Double(step))
            let current = QueueEngine.position(
                anchorPosition: anchorPosition,
                anchorDate: anchorDate,
                at: fireDate
            )
            defer { previous = current }

            guard let content = content(from: previous, to: current) else { continue }
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: fireDate.timeIntervalSince(now),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: "queue-\(step)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)

            // 先頭に着いたらそれ以上は知らせることがない。
            if current == 0 { break }
        }
    }

    private static func content(from previous: Int, to current: Int) -> UNMutableNotificationContent? {
        let content = UNMutableNotificationContent()
        content.sound = .default

        if current == 0 {
            content.title = "先頭になりました"
            content.body = "窓口が空いています。"
        } else if current > previous {
            content.title = "追い抜かれました"
            content.body = "\(current - previous)人に割り込まれました。"
        } else if current < previous {
            content.title = "列が進みました"
            content.body = "\(previous - current)人進んで、\(current.formatted())人目になりました。"
        } else {
            // 深夜など、まったく進まなかった時間帯は黙っている。
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
