import SwiftUI

/// 列に並んでいる世界そのもの。
///
/// 手前に後ろの人、中ほどに自分、その先に前の人が続き、
/// 奥は地平線まで人で埋まっている。景色は進むにつれて移り変わる。
struct QueueWorldView: View {
    let anchorProgress: Int
    let anchorDate: Date
    /// 前の人を叩いたときなどに一瞬だけ姿勢を崩す。
    let disturbance: Double
    let onTapPersonAhead: () -> Void

    /// 自分より後ろに見える人数。
    private static let behindCount = 2
    /// 自分より前に描く人数。これ以上奥は点になって見分けられない。
    private static let aheadCount = 42

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.08)) { timeline in
            Canvas { context, size in
                draw(in: context, size: size, date: timeline.date)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTapPersonAhead() }
    }

    private func draw(in context: GraphicsContext, size: CGSize, date: Date) {
        let served = QueueEngine.servedCountExact(from: anchorDate, to: date)
        let progressExact = min(Double(QueueWorld.length), Double(anchorProgress) + served)
        let progress = Int(progressExact)
        let remaining = QueueWorld.length - progress
        let time = date.timeIntervalSince1970

        let horizonY = size.height * 0.34
        let stage = QueueWorld.stage(at: progress)

        drawScenery(
            stage: stage,
            progress: progress,
            in: context,
            size: size,
            horizonY: horizonY,
            scroll: progressExact,
            time: time
        )

        drawQueue(
            in: context,
            size: size,
            horizonY: horizonY,
            remaining: remaining,
            time: time
        )
    }

    // MARK: - 景色

    /// 場所が切り替わる境目では、前の景色を薄く重ねて繋ぐ。
    private func drawScenery(
        stage: WorldStage,
        progress: Int,
        in context: GraphicsContext,
        size: CGSize,
        horizonY: Double,
        scroll: Double,
        time: Double
    ) {
        let blend = QueueWorld.entryBlend(at: progress)
        let index = QueueWorld.stageIndex(at: progress)

        if blend < 1, index > 0 {
            SceneryRenderer.draw(
                kind: QueueWorld.stages[index - 1].kind,
                in: context,
                size: size,
                horizonY: horizonY,
                scroll: scroll,
                time: time
            )
        }

        var layer = context
        layer.opacity = blend
        SceneryRenderer.draw(
            kind: stage.kind,
            in: layer,
            size: size,
            horizonY: horizonY,
            scroll: scroll,
            time: time
        )
    }

    // MARK: - 列

    private func drawQueue(
        in context: GraphicsContext,
        size: CGSize,
        horizonY: Double,
        remaining: Int,
        time: Double
    ) {
        let baseY = size.height * 1.12
        let centerX = size.width / 2
        let slotCount = Double(Self.behindCount + Self.aheadCount)

        // 奥の人から描いて、手前の人が重なるようにする。
        for slot in stride(from: Self.aheadCount, through: -Self.behindCount, by: -1) {
            let t = (Double(slot) + Double(Self.behindCount)) / slotCount
            let depth = pow(max(t, 0), 0.42)
            let scale = pow(max(0, 1 - depth), 1.3)
            guard scale > 0.001 else { continue }

            let feetY = baseY - (baseY - horizonY) * depth
            let height = size.height * 0.30 * scale
            guard height > 3 else { continue }

            let isPlayer = slot == 0
            let queueIndex = remaining - slot
            guard queueIndex >= 0 else { continue }

            let person = isPlayer ? PersonFactory.player : PersonFactory.person(atQueueIndex: queueIndex)
            let lateral = person.lateralOffset * size.width * 0.05 * scale
            let feet = CGPoint(x: centerX + lateral, y: feetY)

            // 叩かれた直後の前の人だけ、少し身をよじる。
            let jolt = (slot == 1) ? disturbance : 0
            let personTime = time + jolt * 6

            PersonRenderer.draw(
                person,
                in: context,
                feet: feet,
                height: height * person.heightScale,
                time: personTime,
                fade: fade(atDepth: depth)
            )

            if isPlayer {
                drawPlayerMarker(in: context, feet: feet, height: height * person.heightScale)
            }
        }
    }

    /// 奥ほど景色に溶けていく。
    private func fade(atDepth depth: Double) -> Double {
        max(0.16, 1 - depth * 0.72)
    }

    private func drawPlayerMarker(in context: GraphicsContext, feet: CGPoint, height: Double) {
        let top = feet.y - height
        let markerSize = height * 0.13

        var arrow = Path()
        arrow.move(to: CGPoint(x: feet.x - markerSize * 0.5, y: top - markerSize * 1.5))
        arrow.addLine(to: CGPoint(x: feet.x + markerSize * 0.5, y: top - markerSize * 1.5))
        arrow.addLine(to: CGPoint(x: feet.x, y: top - markerSize * 0.6))
        arrow.closeSubpath()
        context.fill(arrow, with: .color(AppTheme.stamp))

        context.draw(
            Text("あなた")
                .font(.system(size: max(9, markerSize * 0.9), weight: .bold))
                .foregroundColor(AppTheme.stamp),
            at: CGPoint(x: feet.x, y: top - markerSize * 2.3)
        )
    }
}
