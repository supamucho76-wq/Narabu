import SwiftUI
import UIKit

/// 手すりをつたう。
///
/// 曲がりくねった通路を、指を離さずに左から右へなぞる。
/// 道から外れると、そこで止まる。**戻って入り直せば続けられる**ので、
/// 一度の失敗で終わらない。
struct TraceGame: View {
    let seconds: Double
    /// 道の広さ。舞台の高さに対する割合。
    let width: Double
    let onFinish: (Bool) -> Void

    /// ここまで来たら着いたと見なす。指が端まで届かない端末を考えて、少し手前。
    private static let goal: Double = 0.94

    @State private var progress: Double = 0
    @State private var isOffTrack = false
    @State private var isDone = false

    var body: some View {
        VStack(spacing: 14) {
            MissionParts.track(ratio: progress / Self.goal)

            MissionParts.stage(height: 200) {
                GeometryReader { geometry in
                    let band = geometry.size.height * width

                    ZStack {
                        // 通路
                        path(in: geometry.size)
                            .stroke(
                                isOffTrack
                                    ? Color(red: 0.86, green: 0.30, blue: 0.26).opacity(0.30)
                                    : AppTheme.ink.opacity(0.12),
                                style: StrokeStyle(lineWidth: band, lineCap: .round)
                            )

                        // 通ってきたところ
                        path(in: geometry.size)
                            .trim(from: 0, to: min(1, progress))
                            .stroke(
                                AppTheme.stamp.opacity(0.55),
                                style: StrokeStyle(lineWidth: band, lineCap: .round)
                            )

                        // いまいる場所
                        Circle()
                            .fill(isOffTrack ? Color(red: 0.86, green: 0.30, blue: 0.26) : AppTheme.stamp)
                            .frame(width: 26, height: 26)
                            .position(point(at: progress, in: geometry.size))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                follow(value.location, in: geometry.size, band: band)
                            }
                            .onEnded { _ in isOffTrack = false }
                    )
                }
            }

            Text("道の上を指でなぞって、右の端まで行く")
                .font(.caption)
                .foregroundStyle(AppTheme.inkSecondary)

            MissionParts.countdown(seconds: seconds) { finish(progress >= Self.goal) }
        }
    }

    // MARK: - 道

    /// 道の形。左から右へ、上下に2度うねる。
    private func curve(at ratio: Double) -> Double {
        0.5 + sin(ratio * .pi * 2.2) * 0.28
    }

    private func point(at ratio: Double, in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * ratio, y: size.height * curve(at: ratio))
    }

    private func path(in size: CGSize) -> Path {
        Path { path in
            path.move(to: point(at: 0, in: size))
            for step in 1...60 {
                path.addLine(to: point(at: Double(step) / 60, in: size))
            }
        }
    }

    // MARK: - 進行

    private func follow(_ location: CGPoint, in size: CGSize, band: Double) {
        guard !isDone else { return }

        let ratio = min(1, max(0, location.x / max(1, size.width)))
        let expected = size.height * curve(at: ratio)
        let onTrack = abs(location.y - expected) <= band / 2

        isOffTrack = !onTrack
        guard onTrack else { return }

        // 戻るぶんは数えない。飛ばしすぎも数えない。
        guard ratio > progress, ratio - progress < 0.2 else { return }
        progress = ratio

        if progress >= Self.goal {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            finish(true)
        }
    }

    private func finish(_ success: Bool) {
        guard !isDone else { return }
        isDone = true
        onFinish(success)
    }
}
