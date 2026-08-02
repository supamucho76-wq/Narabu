import SwiftUI
import UIKit

/// 落とし物をひろう。
///
/// 足元に現れたものを、次々にタップして拾う。
/// ひとつ拾うと次が別の場所に現れるので、**指を運ぶ距離**が忙しさになる。
struct PluckGame: View {
    let count: Int
    let seconds: Double
    let onFinish: (Bool) -> Void

    /// 拾えるものの大きさ。指で狙える大きさにしておく。
    private static let itemSize: Double = 58

    @State private var picked = 0
    @State private var isDone = false

    var body: some View {
        VStack(spacing: 14) {
            MissionParts.counter(picked, of: count)
            MissionParts.track(ratio: Double(picked) / Double(count))

            MissionParts.stage(height: 190) {
                GeometryReader { geometry in
                    TimelineView(.animation) { timeline in
                        let spot = position(of: picked, in: geometry.size)
                        // 拾われるのを待っている物は、ゆっくり息をしている。
                        let pulse = 1 + sin(timeline.date.timeIntervalSinceReferenceDate * 4) * 0.06

                        ZStack {
                            Circle()
                                .fill(AppTheme.stamp.opacity(0.18))
                                .frame(width: Self.itemSize * 1.5, height: Self.itemSize * 1.5)
                                .scaleEffect(pulse)

                            Circle()
                                .fill(AppTheme.stamp)
                                .frame(width: Self.itemSize, height: Self.itemSize)
                                .overlay {
                                    Image(systemName: symbolName(for: picked))
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                        }
                        // 当たり判定を先に決めてから置く。
                        // 置いてから決めると、舞台全体が当たり判定になってしまう。
                        .contentShape(Circle())
                        .onTapGesture { pick() }
                        .position(spot)
                    }
                }
            }

            Text("現れたものをタップして拾う")
                .font(.caption)
                .foregroundStyle(AppTheme.inkSecondary)

            MissionParts.countdown(seconds: seconds) { finish(picked >= count) }
        }
    }

    /// 落ちている場所。並び順から決まるので、同じ場面では同じ順路になる。
    private func position(of index: Int, in size: CGSize) -> CGPoint {
        let margin = Self.itemSize * 0.75
        let x = QueueEngine.unitRandom(index, salt: 0x7D01)
        let y = QueueEngine.unitRandom(index, salt: 0x7D02)
        return CGPoint(
            x: margin + (size.width - margin * 2) * x,
            y: margin + (size.height - margin * 2) * y
        )
    }

    private func symbolName(for index: Int) -> String {
        let names = ["handbag.fill", "key.fill", "eyeglasses", "wallet.pass.fill", "umbrella.fill"]
        let pick = Int(QueueEngine.unitRandom(index, salt: 0x7D03) * Double(names.count))
        return names[min(pick, names.count - 1)]
    }

    private func pick() {
        guard !isDone else { return }

        picked += 1
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if picked >= count { finish(true) }
    }

    private func finish(_ success: Bool) {
        guard !isDone else { return }
        isDone = true
        onFinish(success)
    }
}
