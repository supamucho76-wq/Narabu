import SwiftUI
import UIKit

/// 警備員をやり過ごす。
///
/// 見られていない隙だけ前に詰める。見られている最中に動くと見つかる。
/// 押している間だけ進み、赤くなったら手を離す。
struct HideGame: View {
    let seconds: Double
    let onFinish: (Bool) -> Void

    /// 進みきるのに必要な、忍び足の合計時間。
    private static let requiredCreep: Double = 2.6

    @State private var creep: Double = 0
    @State private var isMoving = false
    @State private var lastUpdate = Date()
    @State private var startedAt = Date()
    @State private var isDone = false

    var body: some View {
        VStack(spacing: 14) {
            MissionParts.stage(height: 170) {
                TimelineView(.animation) { timeline in
                    let watching = isWatching(at: timeline.date)

                    VStack(spacing: 12) {
                        Image(systemName: watching ? "eye.fill" : "eye.slash.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(watching
                                             ? Color(red: 0.88, green: 0.26, blue: 0.22)
                                             : Color(red: 0.42, green: 0.72, blue: 0.52))

                        Text(watching ? "見られている" : "いまなら進める")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.ink)

                        MissionParts.track(
                            ratio: creep / Self.requiredCreep,
                            tint: watching ? Color(red: 0.88, green: 0.26, blue: 0.22) : AppTheme.stamp
                        )
                        .padding(.horizontal, 30)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task(id: Int(timeline.date.timeIntervalSince(startedAt) * 20)) {
                        advance(at: timeline.date, watching: watching)
                    }
                }
            }

            // 押している間だけ進む。離すのは自分の判断。
            Text("押している間だけ進む")
                .font(.caption)
                .foregroundStyle(AppTheme.inkSecondary)

            Rectangle()
                .fill(isMoving ? AppTheme.stamp : AppTheme.ink)
                .frame(maxWidth: .infinity, minHeight: 64)
                .overlay {
                    Text(isMoving ? "進んでいる" : "押して進む")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isMoving {
                                isMoving = true
                                lastUpdate = Date()
                            }
                        }
                        .onEnded { _ in isMoving = false }
                )

            MissionParts.countdown(seconds: seconds) { finish(false) }
        }
        .onAppear {
            startedAt = Date()
            lastUpdate = Date()
        }
    }

    /// 警備員の視線。一定の周期で振り返る。
    private func isWatching(at date: Date) -> Bool {
        let t = date.timeIntervalSince(startedAt)
        // 見ている時間のほうが短いので、待てば必ず隙がくる。
        return t.truncatingRemainder(dividingBy: 2.4) > 1.5
    }

    private func advance(at date: Date, watching: Bool) {
        guard !isDone else { return }

        let elapsed = date.timeIntervalSince(lastUpdate)
        lastUpdate = date
        guard isMoving else { return }

        if watching {
            // 見られている最中に動くと、そこで終わり。
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            finish(false)
            return
        }

        creep += elapsed
        if creep >= Self.requiredCreep { finish(true) }
    }

    private func finish(_ success: Bool) {
        guard !isDone else { return }
        isDone = true
        isMoving = false
        onFinish(success)
    }
}
