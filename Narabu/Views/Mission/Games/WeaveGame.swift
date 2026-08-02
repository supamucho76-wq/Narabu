import SwiftUI
import UIKit

/// 人の間をすり抜ける。
///
/// 左右を交互にタップして、体を斜めにしながらねじ込んでいく。
/// **同じ側を続けて押すと通れない。** 連打で抜けられないのがこの遊びの肝。
struct WeaveGame: View {
    let count: Int
    let seconds: Double
    let onFinish: (Bool) -> Void

    @State private var cleared = 0
    /// 次に押すべき側。左から始める。
    @State private var nextIsLeft = true
    @State private var wrongSide: Bool?
    @State private var isDone = false

    var body: some View {
        VStack(spacing: 14) {
            MissionParts.counter(cleared, of: count)
            MissionParts.track(ratio: Double(cleared) / Double(count))

            MissionParts.stage(height: 150) {
                VStack(spacing: 10) {
                    Image(systemName: nextIsLeft ? "arrow.left" : "arrow.right")
                        .font(.system(size: 44, weight: .black))
                        .foregroundStyle(AppTheme.stamp)
                    Text(nextIsLeft ? "つぎは左" : "つぎは右")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                }
            }

            HStack(spacing: 12) {
                sideButton(isLeft: true)
                sideButton(isLeft: false)
            }

            MissionParts.countdown(seconds: seconds) { finish(cleared >= count) }
        }
    }

    private func sideButton(isLeft: Bool) -> some View {
        let isNext = nextIsLeft == isLeft
        let isWrong = wrongSide == isLeft

        return Button {
            tap(isLeft: isLeft)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: isLeft ? "chevron.left" : "chevron.right")
                    .font(.system(size: 22, weight: .black))
                Text(isLeft ? "左" : "右")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(background(isNext: isNext, isWrong: isWrong))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(GameButtonStyle())
    }

    private func background(isNext: Bool, isWrong: Bool) -> Color {
        if isWrong { return Color(red: 0.86, green: 0.30, blue: 0.26) }
        return isNext ? AppTheme.stamp : AppTheme.ink.opacity(0.35)
    }

    private func tap(isLeft: Bool) {
        guard !isDone else { return }

        if isLeft == nextIsLeft {
            cleared += 1
            nextIsLeft.toggle()
            wrongSide = nil
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if cleared >= count { finish(true) }
        } else {
            // 間違えても止めない。少し戻して、押す側は変えない。
            cleared = max(0, cleared - 1)
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            withAnimation(.easeOut(duration: 0.1)) { wrongSide = isLeft }
            withAnimation(.easeIn(duration: 0.3).delay(0.1)) { wrongSide = nil }
        }
    }

    private func finish(_ success: Bool) {
        guard !isDone else { return }
        isDone = true
        onFinish(success)
    }
}
