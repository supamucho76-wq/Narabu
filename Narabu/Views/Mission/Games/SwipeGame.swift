import SwiftUI
import UIKit

/// 人混みを押し分ける。
///
/// 示された向きへ続けてスワイプする。向きを間違えると進みが少し戻る。
struct SwipeGame: View {
    let count: Int
    let seconds: Double
    let onFinish: (Bool) -> Void

    @State private var cleared = 0
    @State private var wrongFlash = false
    @State private var isDone = false

    /// 次に求められる向き。毎回ばらつくが、同じ場面では同じ順番になる。
    private var required: SwipeDirection {
        let options: [SwipeDirection] = [.left, .right]
        let index = Int(QueueEngine.unitRandom(cleared, salt: 0x2B7C) * Double(options.count))
        return options[min(index, options.count - 1)]
    }

    var body: some View {
        VStack(spacing: 14) {
            MissionParts.counter(cleared, of: count)
            MissionParts.track(ratio: Double(cleared) / Double(count))

            MissionParts.stage {
                VStack(spacing: 10) {
                    Image(systemName: required.symbolName)
                        .font(.system(size: 46, weight: .black))
                        .foregroundStyle(wrongFlash ? Color(red: 0.86, green: 0.3, blue: 0.26) : AppTheme.stamp)
                    Text(required.label + "スワイプ")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                }
            }
            // 舞台のどこを払っても反応する。
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in handle(SwipeDirection.of(value.translation)) }
            )

            MissionParts.countdown(seconds: seconds) { finish(false) }
        }
    }

    private func handle(_ direction: SwipeDirection?) {
        guard !isDone, let direction else { return }

        if direction == required {
            cleared += 1
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if cleared >= count { finish(true) }
        } else {
            // 間違えても止めない。少し戻すだけ。
            cleared = max(0, cleared - 1)
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            withAnimation(.easeOut(duration: 0.1)) { wrongFlash = true }
            withAnimation(.easeIn(duration: 0.3).delay(0.1)) { wrongFlash = false }
        }
    }

    private func finish(_ success: Bool) {
        guard !isDone else { return }
        isDone = true
        onFinish(success)
    }
}
