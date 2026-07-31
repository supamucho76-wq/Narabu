import SwiftUI
import UIKit

/// 落ちてくるものを避け続ける。
///
/// 指を左右に滑らせて自分を動かす。制限時間まで当たらなければ成功。
struct DodgeGame: View {
    let seconds: Double
    let onFinish: (Bool) -> Void

    /// 同時に落ちてくる数。
    private static let laneCount = 5
    /// 当たったと見なす近さ。
    private static let hitRadius = 0.11

    @State private var playerX: Double = 0.5
    @State private var startedAt = Date()
    @State private var wasHit = false
    @State private var isDone = false

    var body: some View {
        VStack(spacing: 14) {
            MissionParts.stage(height: 200) {
                TimelineView(.animation) { timeline in
                    let elapsed = timeline.date.timeIntervalSince(startedAt)

                    GeometryReader { geometry in
                        ZStack(alignment: .topLeading) {
                            ForEach(0..<Self.laneCount, id: \.self) { lane in
                                let drop = position(of: lane, elapsed: elapsed)
                                Image(systemName: symbol(for: lane))
                                    .font(.system(size: 22))
                                    .foregroundStyle(AppTheme.ink.opacity(0.75))
                                    .position(
                                        x: geometry.size.width * drop.x,
                                        y: geometry.size.height * drop.y
                                    )
                            }

                            // 自分
                            Image(systemName: "figure.stand")
                                .font(.system(size: 30))
                                .foregroundStyle(wasHit ? Color(red: 0.86, green: 0.3, blue: 0.26) : AppTheme.stamp)
                                .position(
                                    x: geometry.size.width * playerX,
                                    y: geometry.size.height * 0.88
                                )
                        }
                        .task(id: Int(elapsed * 20)) {
                            check(elapsed: elapsed)
                        }
                        // 押さえた場所へ素直に動かす。幅は実際の枠から取る。
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let ratio = value.location.x / max(1, geometry.size.width)
                                    playerX = min(0.94, max(0.06, ratio))
                                }
                        )
                    }
                }
            }

            Text("指を左右に滑らせて避ける")
                .font(.caption)
                .foregroundStyle(AppTheme.inkSecondary)

            MissionParts.countdown(until: startedAt.addingTimeInterval(seconds)) { finish(true) }
        }
        .onAppear { startedAt = Date() }
    }

    /// 落ちてくるものの位置。時刻から決まるので、状態を持たなくていい。
    private func position(of lane: Int, elapsed: Double) -> (x: Double, y: Double) {
        let speed = 0.42 + QueueEngine.unitRandom(lane, salt: 0x5A2B) * 0.3
        let offset = QueueEngine.unitRandom(lane, salt: 0x6B3C)
        let cycle = (elapsed * speed + offset).truncatingRemainder(dividingBy: 1)
        // 落ちるたびに左右の位置が変わる。
        let round = Int(elapsed * speed + offset)
        let x = 0.1 + QueueEngine.unitRandom(lane &* 31 &+ round, salt: 0x7C4D) * 0.8
        return (x, cycle)
    }

    private func symbol(for lane: Int) -> String {
        let symbols = ["bag.fill", "cup.and.saucer.fill", "umbrella.fill", "book.fill", "handbag.fill"]
        return symbols[lane % symbols.count]
    }

    /// 足元に重なったら失敗。
    private func check(elapsed: Double) {
        guard !isDone else { return }

        for lane in 0..<Self.laneCount {
            let drop = position(of: lane, elapsed: elapsed)
            guard drop.y > 0.78, drop.y < 0.96 else { continue }
            guard abs(drop.x - playerX) < Self.hitRadius else { continue }

            wasHit = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            finish(false)
            return
        }
    }

    private func finish(_ success: Bool) {
        guard !isDone else { return }
        isDone = true
        onFinish(success)
    }
}
