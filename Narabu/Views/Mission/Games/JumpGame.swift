import SwiftUI
import UIKit

/// 前の人のスーツケースを飛び越える。
///
/// 荷物が足元に重なった瞬間にタップする。3回続けて跳べたら成功。
struct JumpGame: View {
    let speed: Double
    /// 跳べる幅。狭いほど難しい。
    let window: Double
    let onFinish: (Bool) -> Void

    /// 跳ぶ位置。ここに荷物が重なった瞬間が正解。
    private static let jumpPoint = 0.28
    private static let required = 3

    @State private var cleared = 0
    @State private var missed = 0
    @State private var startedAt = Date()
    @State private var lastResult: Bool?
    @State private var isDone = false

    var body: some View {
        VStack(spacing: 14) {
            MissionParts.counter(cleared, of: Self.required)

            MissionParts.stage {
                TimelineView(.animation) { timeline in
                    let position = obstaclePosition(at: timeline.date)

                    GeometryReader { geometry in
                        ZStack(alignment: .bottomLeading) {
                            // 跳ぶ位置の目印
                            Rectangle()
                                .fill(AppTheme.stamp.opacity(0.2))
                                .frame(width: geometry.size.width * window)
                                .offset(x: geometry.size.width * (Self.jumpPoint - window / 2))

                            // 自分
                            Image(systemName: "figure.walk")
                                .font(.system(size: 30))
                                .foregroundStyle(AppTheme.ink)
                                .offset(
                                    x: geometry.size.width * Self.jumpPoint - 14,
                                    y: lastResult == true ? -34 : -8
                                )
                                .animation(.easeOut(duration: 0.18), value: lastResult)

                            // 荷物
                            Image(systemName: "suitcase.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(Color(red: 0.52, green: 0.34, blue: 0.24))
                                .offset(x: geometry.size.width * position - 12, y: -6)
                        }
                        .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                    .padding(.bottom, 12)
                }
            }

            MissionParts.bigButton("跳ぶ") { jump() }

            Text("失敗 \(missed) / 3")
                .font(.caption2)
                .foregroundStyle(AppTheme.inkSecondary)
        }
        .onAppear { startedAt = Date() }
    }

    /// 荷物は右から左へ、一定の速さで流れてくる。
    private func obstaclePosition(at date: Date) -> Double {
        let t = date.timeIntervalSince(startedAt) * speed
        return 1.15 - t.truncatingRemainder(dividingBy: 1.5) / 1.5 * 1.3
    }

    private func jump() {
        guard !isDone else { return }

        let position = obstaclePosition(at: Date())
        let hit = abs(position - Self.jumpPoint) <= window / 2

        lastResult = hit
        if hit {
            cleared += 1
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            if cleared >= Self.required { finish(true) }
        } else {
            missed += 1
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            if missed >= 3 { finish(false) }
        }

        // 跳んだ姿勢を戻す。
        Task {
            try? await Task.sleep(for: .seconds(0.25))
            lastResult = nil
        }
    }

    private func finish(_ success: Bool) {
        guard !isDone else { return }
        isDone = true
        onFinish(success)
    }
}
