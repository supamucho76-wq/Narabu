import SwiftUI

enum AppRuntime {
    static let isUITesting = CommandLine.arguments.contains("--ui-testing")
}

@main
@MainActor
struct NarabuApp: App {
    @State private var queue = QueueStore()
    @State private var purchases = PurchaseStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            QueueView()
                .environment(queue)
                .environment(purchases)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                // 閉じている間も列は進んでいるので、まず現在地を計算し直す。
                queue.refresh()
                queue.startTicking()
            case .background, .inactive:
                queue.stopTicking()
            @unknown default:
                break
            }
        }
    }
}
