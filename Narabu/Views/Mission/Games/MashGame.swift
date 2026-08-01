import SwiftUI
import UIKit

/// 人混みをこじ開けて抜ける。
///
/// 制限時間内に指定回数タップする。
struct MashGame: View {
    let target: Int
    let seconds: Double
    let onFinish: (Bool) -> Void

    @State private var taps = 0
    @State private var isDone = false

    var body: some View {
        VStack(spacing: 14) {
            MissionParts.counter(taps, of: target)
            MissionParts.track(ratio: Double(taps) / Double(target))
            MissionParts.countdown(seconds: seconds) { finish(taps >= target) }

            MissionParts.bigButton("タップ") {
                guard !isDone else { return }
                taps += 1
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if taps >= target { finish(true) }
            }
        }
    }

    private func finish(_ success: Bool) {
        guard !isDone else { return }
        isDone = true
        onFinish(success)
    }
}
