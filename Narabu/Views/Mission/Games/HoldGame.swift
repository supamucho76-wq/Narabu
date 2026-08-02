import SwiftUI
import UIKit

/// 荷物を担ぎ上げる。
///
/// 押している間だけ力が入り、目盛りが伸びていく。
/// 帯の中で指を離せば担ぎ上がる。行き過ぎると腰をやられて落とす。
///
/// 押す・離すの2動作だけで、**離す瞬間を自分で決める**のが他と違うところ。
struct HoldGame: View {
    /// 狙う位置。0〜1。
    let target: Double
    /// 合っていると見なす幅。
    let tolerance: Double
    let onFinish: (Bool) -> Void

    /// 目盛りが端まで伸びきるのにかかる時間。
    private static let fillSeconds: Double = 2.4

    /// 押し始めた時刻。押していないあいだは nil。
    @State private var pressedAt: Date?
    /// 離したあとの目盛り。判定に使う。
    @State private var released: Double?
    @State private var isDone = false

    var body: some View {
        VStack(spacing: 14) {
            MissionParts.stage(height: 170) {
                GeometryReader { geometry in
                    TimelineView(.animation) { timeline in
                        let value = released ?? effort(at: timeline.date)
                        let inBand = abs(value - target) <= tolerance

                        ZStack(alignment: .leading) {
                            // 目盛りの土台
                            Capsule()
                                .fill(AppTheme.ink.opacity(0.10))

                            // 狙う帯
                            Rectangle()
                                .fill(inBand
                                      ? Color(red: 0.30, green: 0.68, blue: 0.44).opacity(0.45)
                                      : AppTheme.stamp.opacity(0.28))
                                .frame(
                                    width: geometry.size.width * tolerance * 2,
                                    height: 40
                                )
                                .offset(x: geometry.size.width * (target - tolerance))

                            // いま入っている力
                            Capsule()
                                .fill(inBand ? Color(red: 0.30, green: 0.68, blue: 0.44) : AppTheme.stamp)
                                .frame(width: geometry.size.width * min(1, value))
                        }
                        .frame(height: 40)
                        .frame(maxHeight: .infinity)
                        .task(id: Int(value * 200)) { checkOverflow(value) }
                    }
                }
                .padding(.horizontal, 16)
            }

            Text("押すと力が入る。帯の中で離す")
                .font(.caption)
                .foregroundStyle(AppTheme.inkSecondary)

            Rectangle()
                .fill(pressedAt == nil ? AppTheme.ink : AppTheme.stamp)
                .frame(maxWidth: .infinity, minHeight: 64)
                .overlay {
                    Text(pressedAt == nil ? "押して力を入れる" : "離す")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            guard !isDone, pressedAt == nil else { return }
                            pressedAt = Date()
                        }
                        .onEnded { _ in release() }
                )
        }
    }

    /// いま入っている力。押していなければ0。
    private func effort(at date: Date) -> Double {
        guard let pressedAt else { return 0 }
        return date.timeIntervalSince(pressedAt) / Self.fillSeconds
    }

    /// 端まで伸びきったら、待たずに失敗にする。
    private func checkOverflow(_ value: Double) {
        guard !isDone, released == nil, value >= 1 else { return }
        released = 1
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        finish(false)
    }

    private func release() {
        guard !isDone, let pressedAt else { return }

        let value = Date().timeIntervalSince(pressedAt) / Self.fillSeconds
        released = min(1, value)
        self.pressedAt = nil

        let matched = abs(value - target) <= tolerance
        UINotificationFeedbackGenerator().notificationOccurred(matched ? .success : .warning)
        finish(matched)
    }

    private func finish(_ success: Bool) {
        guard !isDone else { return }
        isDone = true
        onFinish(success)
    }
}
