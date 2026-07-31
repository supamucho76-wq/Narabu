import SwiftUI
import UIKit

/// エスカレーターを駆け上がる。
///
/// 上へこすり上げるたびに進むが、手を止めると流されて戻る。
/// 押し続けるのではなく、こすり続けるのが要る。
struct EscalatorGame: View {
    let seconds: Double
    let onFinish: (Bool) -> Void

    /// 1回のこすりで進むぶん。
    private static let gainPerSwipe = 0.11
    /// 1秒あたり流されるぶん。
    private static let slipPerSecond = 0.075

    @State private var height: Double = 0
    @State private var lastUpdate = Date()
    @State private var startedAt = Date()
    @State private var isDone = false

    var body: some View {
        VStack(spacing: 14) {
            MissionParts.stage(height: 190) {
                GeometryReader { geometry in
                    TimelineView(.animation) { timeline in
                        ZStack(alignment: .bottom) {
                            // 段
                            ForEach(0..<7, id: \.self) { step in
                                Rectangle()
                                    .fill(AppTheme.ink.opacity(0.08))
                                    .frame(height: 3)
                                    .offset(y: -geometry.size.height * (0.1 + Double(step) * 0.12))
                            }

                            Image(systemName: "figure.stair.stepper")
                                .font(.system(size: 32))
                                .foregroundStyle(AppTheme.stamp)
                                .offset(y: -geometry.size.height * (0.06 + height * 0.78))
                                .animation(.easeOut(duration: 0.15), value: height)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .task(id: Int(timeline.date.timeIntervalSince(startedAt) * 12)) {
                            slip(at: timeline.date)
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 18)
                    .onEnded { value in
                        if SwipeDirection.of(value.translation) == .up { climb() }
                    }
            )

            MissionParts.track(ratio: height)

            Text("上へこすり上げる。止まると流される")
                .font(.caption)
                .foregroundStyle(AppTheme.inkSecondary)

            MissionParts.countdown(until: startedAt.addingTimeInterval(seconds)) { finish(false) }
        }
        .onAppear {
            startedAt = Date()
            lastUpdate = Date()
        }
    }

    private func climb() {
        guard !isDone else { return }
        height = min(1, height + Self.gainPerSwipe)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if height >= 1 { finish(true) }
    }

    /// 手を止めているあいだ、少しずつ下がる。
    private func slip(at date: Date) {
        guard !isDone else { return }
        let elapsed = date.timeIntervalSince(lastUpdate)
        lastUpdate = date
        height = max(0, height - elapsed * Self.slipPerSecond)
    }

    private func finish(_ success: Bool) {
        guard !isDone else { return }
        isDone = true
        onFinish(success)
    }
}
