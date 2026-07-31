import SwiftUI

enum AppRuntime {
    static let isUITesting = CommandLine.arguments.contains("--ui-testing")
}

@main
@MainActor
struct NarabuApp: App {
    @State private var queue = QueueStore()
    @State private var purchases = PurchaseStore()
    @State private var sound = SoundPlayer()
    @State private var voice = VoiceRecognizer()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            QueueView()
                // 画面はすべて紙と墨の配色で組んでいる。
                // 端末が暗い配色だと、背景は紙のままで文字だけが明るく反転して読めなくなる。
                // 配色を明るい側に固定して、標準の部品も同じ前提で描かせる。
                .preferredColorScheme(.light)
                .environment(queue)
                .environment(purchases)
                .environment(sound)
                .environment(voice)
                .task {
                    // 録音のあいだは、再生用のエンジンに場所を空けてもらう。
                    voice.onWillRecord = { [sound] in sound.suspendForRecording() }
                    voice.onDidFinishRecording = { [sound] in sound.resumeAfterRecording() }
                }
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
