import SwiftUI
import UIKit

/// 列が動いた瞬間に詰める。
///
/// 往復する針を、当たり範囲で止める。
struct TimingGame: View {
    let targetWidth: Double
    let speed: Double
    let onFinish: (Bool) -> Void

    @State private var target: Double = 0.5
    @State private var stoppedAt: Date?
    @State private var isDone = false

    var body: some View {
        VStack(spacing: 18) {
            MissionParts.stage(height: 120) {
                TimelineView(.animation) { timeline in
                    let position = needlePosition(at: stoppedAt ?? timeline.date)

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AppTheme.ink.opacity(0.10))

                            Capsule()
                                .fill(AppTheme.stamp.opacity(0.35))
                                .frame(width: geometry.size.width * targetWidth)
                                .offset(x: geometry.size.width * (target - targetWidth / 2))

                            Capsule()
                                .fill(AppTheme.ink)
                                .frame(width: 4)
                                .offset(x: geometry.size.width * position - 2)
                        }
                        .frame(height: 40)
                        .frame(maxHeight: .infinity)
                    }
                    .padding(.horizontal, 20)
                }
            }

            MissionParts.bigButton("止める") { stop() }
        }
        .onAppear {
            // 当たり範囲は毎回ずらす。真ん中で止める癖がつかないように。
            target = 0.25 + Double.random(in: 0..<1) * 0.5
        }
    }

    /// 針の位置は時刻だけから決まる。毎フレーム状態を書き換えなくていい。
    private func needlePosition(at date: Date) -> Double {
        let t = date.timeIntervalSince1970 * speed
        return 1 - abs(t.truncatingRemainder(dividingBy: 2) - 1)
    }

    private func stop() {
        guard !isDone else { return }

        let now = Date()
        stoppedAt = now
        isDone = true

        let hit = abs(needlePosition(at: now) - target) <= targetWidth / 2
        UINotificationFeedbackGenerator().notificationOccurred(hit ? .success : .warning)
        onFinish(hit)
    }
}
