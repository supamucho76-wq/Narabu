import SwiftUI
import UIKit

/// 荷物を落とさない。
///
/// 天秤棒に載せた荷物が勝手に傾いていく。**下がった側をタップして押し上げる。**
/// 時間まで倒さずに耐えれば成功。
///
/// 傾きは毎フレーム書き換えず、**基準からの積分**で求める。
/// そうしないと描画のたびに状態が変わり、画面が回り続けてしまう。
struct BalanceGame: View {
    let seconds: Double
    /// 傾いていく強さ。
    let drift: Double
    let onFinish: (Bool) -> Void

    /// ここまで傾くと落とす。
    private static let limit: Double = 1.0

    @State private var base: Double = 0
    @State private var baseAt = Date()
    @State private var startedAt = Date()
    @State private var isDone = false

    var body: some View {
        VStack(spacing: 14) {
            MissionParts.stage(height: 190) {
                TimelineView(.animation) { timeline in
                    let tilt = self.tilt(at: timeline.date)
                    let danger = abs(tilt) > 0.62

                    VStack(spacing: 16) {
                        Text(danger ? "落ちる！" : "水平を保つ")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(danger
                                             ? Color(red: 0.88, green: 0.26, blue: 0.22)
                                             : AppTheme.inkSecondary)

                        ZStack {
                            // 荷物
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color(red: 0.72, green: 0.56, blue: 0.34))
                                .frame(width: 46, height: 34)
                                .offset(y: -26)

                            // 天秤棒
                            Capsule()
                                .fill(danger ? Color(red: 0.88, green: 0.26, blue: 0.22) : AppTheme.ink)
                                .frame(width: 190, height: 10)
                        }
                        .rotationEffect(.degrees(tilt * 26))

                        // 傾きの目盛り。真ん中が水平。
                        ZStack(alignment: .center) {
                            Capsule()
                                .fill(AppTheme.ink.opacity(0.10))
                                .frame(height: 6)
                            Circle()
                                .fill(danger ? Color(red: 0.88, green: 0.26, blue: 0.22) : AppTheme.stamp)
                                .frame(width: 14, height: 14)
                                .offset(x: 90 * min(1, max(-1, tilt)))
                        }
                        .frame(width: 200)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task(id: Int(timeline.date.timeIntervalSince(startedAt) * 20)) {
                        checkFall(at: timeline.date)
                    }
                }
            }

            Text("下がっている側をタップして押し上げる")
                .font(.caption)
                .foregroundStyle(AppTheme.inkSecondary)

            HStack(spacing: 12) {
                pushButton(isLeft: true)
                pushButton(isLeft: false)
            }

            MissionParts.countdown(seconds: seconds) { finish(true) }
        }
        .onAppear {
            startedAt = Date()
            baseAt = Date()
        }
    }

    private func pushButton(isLeft: Bool) -> some View {
        Button {
            push(isLeft: isLeft)
        } label: {
            Image(systemName: isLeft ? "arrow.up.left" : "arrow.up.right")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(AppTheme.ink)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(GameButtonStyle())
    }

    // MARK: - 傾き

    /// 勝手に傾いていく量の、時刻までの合計。
    ///
    /// 速さを `drift * (0.6·sin(0.8t) + 0.4·sin(2.1t + 1.3))` と決めておくと、
    /// その合計は式のまま求められる。だから途中の値を持たなくてよい。
    private func driftTotal(_ t: Double) -> Double {
        drift * (-0.75 * cos(0.8 * t) - (0.4 / 2.1) * cos(2.1 * t + 1.3))
    }

    private func tilt(at date: Date) -> Double {
        let now = date.timeIntervalSince(startedAt)
        let from = baseAt.timeIntervalSince(startedAt)
        return base + driftTotal(now) - driftTotal(from)
    }

    private func push(isLeft: Bool) {
        guard !isDone else { return }

        let now = Date()
        // 左が下がっているとき、傾きは負。左を押し上げると0へ戻る。
        let current = tilt(at: now)
        base = current + (isLeft ? 0.34 : -0.34)
        baseAt = now
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func checkFall(at date: Date) {
        guard !isDone else { return }
        guard abs(tilt(at: date)) >= Self.limit else { return }

        UINotificationFeedbackGenerator().notificationOccurred(.error)
        finish(false)
    }

    private func finish(_ success: Bool) {
        guard !isDone else { return }
        isDone = true
        onFinish(success)
    }
}
