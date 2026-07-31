import SwiftUI
import UIKit

/// 整理券を係員に見せる。
///
/// 揺れている読み取り枠に整理券を合わせて、重なったところで見せる。
struct AlignGame: View {
    /// 合っていると見なす近さ。小さいほど難しい。
    let tolerance: Double
    let onFinish: (Bool) -> Void

    @State private var ticketX: Double = 0.5
    @State private var startedAt = Date()
    @State private var isDone = false

    var body: some View {
        VStack(spacing: 14) {
            MissionParts.stage(height: 180) {
                GeometryReader { geometry in
                    TimelineView(.animation) { timeline in
                        let target = framePosition(at: timeline.date)

                        ZStack(alignment: .topLeading) {
                            // 読み取り枠
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(AppTheme.stamp, lineWidth: 3)
                                .frame(width: geometry.size.width * tolerance * 2.2, height: 76)
                                .position(
                                    x: geometry.size.width * target,
                                    y: geometry.size.height * 0.32
                                )

                            // 整理券
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(AppTheme.paper)
                                .overlay {
                                    Image(systemName: "qrcode")
                                        .font(.system(size: 26))
                                        .foregroundStyle(AppTheme.ink)
                                }
                                .frame(width: 58, height: 66)
                                .position(
                                    x: geometry.size.width * ticketX,
                                    y: geometry.size.height * 0.72
                                )
                                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let ratio = value.location.x / max(1, geometry.size.width)
                                    ticketX = min(0.92, max(0.08, ratio))
                                }
                        )
                    }
                }
            }

            Text("整理券を指で動かして、枠に合わせる")
                .font(.caption)
                .foregroundStyle(AppTheme.inkSecondary)

            MissionParts.bigButton("見せる") { show() }
        }
        .onAppear { startedAt = Date() }
    }

    /// 枠は左右に揺れている。時刻から決まるので状態を持たない。
    private func framePosition(at date: Date) -> Double {
        let t = date.timeIntervalSince(startedAt) * 0.85
        let wave = 1 - abs(t.truncatingRemainder(dividingBy: 2) - 1)
        return 0.18 + wave * 0.64
    }

    private func show() {
        guard !isDone else { return }

        let target = framePosition(at: Date())
        let matched = abs(target - ticketX) <= tolerance

        UINotificationFeedbackGenerator().notificationOccurred(matched ? .success : .warning)
        isDone = true
        onFinish(matched)
    }
}
