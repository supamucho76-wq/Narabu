import SwiftUI

/// 前に並んでいる人たちを、奥に向かって描く。
///
/// 列は少しずつ前に詰めていく。人は等間隔に置いてあるので、
/// 1人ぶん進みきった瞬間に全体をひとつ手前へずらしても、絵は変わらない。
/// それを繰り返すことで、途切れずに前進し続けて見える。
struct QueueCrowdView: View {
    let position: Int
    let anchorDate: Date
    let onTapPersonAhead: () -> Void

    /// 画面に描く人数。奥は小さくなって潰れるので、これ以上増やしても見えない。
    private static let visibleCount = 44

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { timeline in
            Canvas { context, size in
                draw(in: &context, size: size, date: timeline.date)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTapPersonAhead() }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, date: Date) {
        let advance = QueueEngine.advanceFraction(anchorDate: anchorDate, at: date)
        let horizonY = size.height * 0.06
        let baseY = size.height * 1.02
        let centerX = size.width / 2
        let elapsed = date.timeIntervalSince1970

        // 奥から手前へ描いて、手前の人が奥の人を隠すようにする。
        for slot in stride(from: Self.visibleCount, through: 0, by: -1) {
            let t = (Double(slot) + advance) / Double(Self.visibleCount)
            guard t <= 1.02 else { continue }

            // 手前をゆったり、奥を詰めて配置すると奥行きが出る。
            let depth = pow(max(t, 0), 0.62)
            let y = baseY - (baseY - horizonY) * depth
            let scale = max(0.035, 1 - depth * 0.94)

            // この人が列の何番目か。進んでも同じ人が同じ癖を保つように、
            // 見た目の乱数は絶対位置に結びつける。
            let personIndex = position - 1 - slot
            guard personIndex >= 0 else { continue }

            let sway = QueueEngine.unitRandom(personIndex, salt: 0x4C1D) - 0.5
            let bobPhase = QueueEngine.unitRandom(personIndex, salt: 0x88E2) * 6.283
            let bob = sin(elapsed * 0.9 + bobPhase) * 1.6 * scale
            let heightVariation = 0.9 + QueueEngine.unitRandom(personIndex, salt: 0x2D77) * 0.24

            let bodyWidth = 46 * scale
            let bodyHeight = 78 * scale * heightVariation
            let x = centerX + sway * size.width * 0.22 * depth.squareRoot()

            drawPerson(
                in: &context,
                x: x,
                bottomY: y + bob,
                width: bodyWidth,
                height: bodyHeight,
                shade: shade(atDepth: depth)
            )
        }
    }

    /// 奥ほど空気に溶けて薄くなる。
    private func shade(atDepth depth: Double) -> Color {
        AppTheme.ink.opacity(max(0.07, 1 - depth * 0.82))
    }

    /// 頭と肩だけの影絵。小さくしても人だとわかる形にしている。
    private func drawPerson(
        in context: inout GraphicsContext,
        x: Double,
        bottomY: Double,
        width: Double,
        height: Double,
        shade: Color
    ) {
        let headDiameter = width * 0.52
        let shoulderWidth = width
        let torsoHeight = height - headDiameter * 1.15

        let torso = Path(
            roundedRect: CGRect(
                x: x - shoulderWidth / 2,
                y: bottomY - torsoHeight,
                width: shoulderWidth,
                height: torsoHeight
            ),
            cornerSize: CGSize(width: shoulderWidth * 0.42, height: shoulderWidth * 0.42)
        )
        context.fill(torso, with: .color(shade))

        let head = Path(
            ellipseIn: CGRect(
                x: x - headDiameter / 2,
                y: bottomY - torsoHeight - headDiameter * 1.05,
                width: headDiameter,
                height: headDiameter
            )
        )
        context.fill(head, with: .color(shade))
    }
}
