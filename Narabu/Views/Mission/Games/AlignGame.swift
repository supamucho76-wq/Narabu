import SwiftUI
import UIKit

/// 整理券を係員に見せる。
///
/// 揺れている読み取り枠に整理券を差し込む。
/// 枠と整理券は同じ高さに並べてあるので、**重なれば整理券が枠の中に収まる**。
struct AlignGame: View {
    /// 合っていると見なす近さ。小さいほど難しい。
    let tolerance: Double
    let onFinish: (Bool) -> Void

    /// 整理券の大きさ。枠は必ずこれより大きく作る。
    private static let ticketWidth: Double = 58
    private static let ticketHeight: Double = 66

    @State private var ticketX: Double = 0.5
    @State private var startedAt = Date()
    @State private var isDone = false

    var body: some View {
        VStack(spacing: 14) {
            MissionParts.stage(height: 180) {
                GeometryReader { geometry in
                    TimelineView(.animation) { timeline in
                        let target = framePosition(at: timeline.date)
                        let matched = abs(target - ticketX) <= tolerance
                        // 枠は整理券より必ず一回り大きく、判定の幅にも合わせる。
                        let frameWidth = max(
                            Self.ticketWidth + 20,
                            geometry.size.width * tolerance * 2
                        )
                        let centerY = geometry.size.height * 0.5

                        ZStack {
                            // 読み取り枠。整理券と同じ高さを左右に揺れる。
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(
                                    matched ? Color(red: 0.30, green: 0.68, blue: 0.44) : AppTheme.stamp,
                                    lineWidth: matched ? 5 : 3
                                )
                                .frame(width: frameWidth, height: Self.ticketHeight + 22)
                                .position(x: geometry.size.width * target, y: centerY)

                            // 整理券。指で左右に動かす。
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(AppTheme.paper)
                                .overlay {
                                    Image(systemName: "qrcode")
                                        .font(.system(size: 26))
                                        .foregroundStyle(AppTheme.ink)
                                }
                                .frame(width: Self.ticketWidth, height: Self.ticketHeight)
                                .position(x: geometry.size.width * ticketX, y: centerY)
                                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)

                            // 合っている瞬間が分かるようにしておく。
                            Text(matched ? "いま！" : "枠に入れる")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(matched
                                                 ? Color(red: 0.24, green: 0.58, blue: 0.38)
                                                 : AppTheme.inkSecondary)
                                .position(x: geometry.size.width * 0.5,
                                          y: geometry.size.height * 0.88)
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
