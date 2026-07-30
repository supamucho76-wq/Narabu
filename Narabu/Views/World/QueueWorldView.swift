import SwiftUI

/// 列に並んでいる世界そのもの。
///
/// 手前に後ろの人、中ほどに自分、その先に前の人が続き、
/// 奥は地平線まで人で埋まっている。景色は進むにつれて移り変わる。
struct QueueWorldView: View {
    let anchorProgress: Int
    let anchorDate: Date
    /// 前の人に絡んだ直後に一瞬だけ姿勢を崩す。
    let disturbance: Double
    let onTapPersonAhead: () -> Void

    /// 自分より後ろに見える人数。
    private static let behindCount = 3
    /// 自分より前に描く人数。これ以上奥は点になって見分けられない。
    private static let aheadCount = 46

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
        let horizonY = size.height * 0.30

        drawScenery(
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
            kind: QueueWorld.stages[index].kind,
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
        let baseY = size.height * 1.18
        let centerX = size.width / 2
        let slotCount = Double(Self.behindCount + Self.aheadCount)

        // 奥の人から描いて、手前の人が重なるようにする。
        for slot in stride(from: Self.aheadCount, through: -Self.behindCount, by: -1) {
            let t = (Double(slot) + Double(Self.behindCount)) / slotCount
            let depth = pow(max(t, 0), 0.42)
            let scale = pow(max(0, 1 - depth), 1.3)
            guard scale > 0.001 else { continue }

            let feetY = baseY - (baseY - horizonY) * depth
            let height = size.height * 0.52 * scale
            guard height > 3 else { continue }

            let isPlayer = slot == 0
            let queueIndex = remaining - slot
            guard queueIndex >= 0 else { continue }

            let person = isPlayer ? PersonFactory.player : PersonFactory.person(atQueueIndex: queueIndex)

            // 列はまっすぐではなく、少しずつ左右にずれて厚みが出る。
            let lateral = person.lateralOffset * size.width * 0.16 * scale
            let feet = CGPoint(x: centerX + lateral, y: feetY)
            let personHeight = height * person.heightScale

            if isPlayer {
                drawPlayerRing(in: context, feet: feet, height: personHeight, time: time)
            }

            // 絡まれた前の人だけ、一瞬身をよじる。
            let jolt = (slot == 1) ? disturbance : 0

            PersonRenderer.draw(
                person,
                in: context,
                feet: feet,
                height: personHeight,
                time: time + jolt * 6,
                fade: fade(atDepth: depth)
            )

            if isPlayer {
                drawPlayerLabel(in: context, feet: feet, height: personHeight)
            } else if slot == 1, !person.remark.isEmpty {
                drawRemark(person.remark, in: context, feet: feet, height: personHeight, size: size)
            }
        }
    }

    /// 奥ほど景色に溶けていく。
    private func fade(atDepth depth: Double) -> Double {
        max(0.18, 1 - depth * 0.7)
    }

    // MARK: - 自分

    /// 足元の光る輪。画面の中で自分がどれかを一目でわからせる。
    private func drawPlayerRing(in context: GraphicsContext, feet: CGPoint, height: Double, time: Double) {
        let pulse = 1 + sin(time * 2.2) * 0.08
        let w = height * 0.52 * pulse
        let h = w * 0.3

        for (index, opacity) in [0.30, 0.55].enumerated() {
            let spread = 1 + Double(index) * 0.35
            context.stroke(
                Path(ellipseIn: CGRect(
                    x: feet.x - w * spread / 2,
                    y: feet.y - h * spread / 2,
                    width: w * spread,
                    height: h * spread
                )),
                with: .color(Color(red: 1.0, green: 0.86, blue: 0.34).opacity(opacity)),
                lineWidth: max(1.5, height * 0.022)
            )
        }
    }

    private func drawPlayerLabel(in context: GraphicsContext, feet: CGPoint, height: Double) {
        let top = feet.y - height
        let markerSize = height * 0.11

        var arrow = Path()
        arrow.move(to: CGPoint(x: feet.x - markerSize * 0.55, y: top - markerSize * 1.6))
        arrow.addLine(to: CGPoint(x: feet.x + markerSize * 0.55, y: top - markerSize * 1.6))
        arrow.addLine(to: CGPoint(x: feet.x, y: top - markerSize * 0.55))
        arrow.closeSubpath()
        context.fill(arrow, with: .color(Color(red: 1.0, green: 0.86, blue: 0.34)))

        context.draw(
            Text("あなた")
                .font(.system(size: max(10, markerSize * 0.95), weight: .heavy))
                .foregroundColor(.white),
            at: CGPoint(x: feet.x, y: top - markerSize * 2.5)
        )
    }

    // MARK: - 前の人の吹き出し

    /// 前の人がぽつりと漏らす一言。進むたびに話し相手が変わる。
    private func drawRemark(
        _ text: String,
        in context: GraphicsContext,
        feet: CGPoint,
        height: Double,
        size: CGSize
    ) {
        let fontSize = max(11.0, min(15.0, height * 0.075))
        let resolved = context.resolve(
            Text(text)
                .font(.system(size: fontSize, weight: .medium))
                .foregroundColor(AppTheme.ink)
        )
        let textSize = resolved.measure(in: CGSize(width: size.width * 0.62, height: 200))

        let padding = fontSize * 0.7
        let bubbleWidth = textSize.width + padding * 2
        let bubbleHeight = textSize.height + padding * 1.4
        let centerX = min(max(feet.x, bubbleWidth / 2 + 8), size.width - bubbleWidth / 2 - 8)
        let bottomY = feet.y - height * 1.08

        let bubble = CGRect(
            x: centerX - bubbleWidth / 2,
            y: bottomY - bubbleHeight,
            width: bubbleWidth,
            height: bubbleHeight
        )
        context.fill(
            Path(roundedRect: bubble, cornerRadius: fontSize * 0.6),
            with: .color(.white.opacity(0.95))
        )

        var tail = Path()
        tail.move(to: CGPoint(x: feet.x - fontSize * 0.35, y: bubble.maxY - 1))
        tail.addLine(to: CGPoint(x: feet.x + fontSize * 0.35, y: bubble.maxY - 1))
        tail.addLine(to: CGPoint(x: feet.x, y: bubble.maxY + fontSize * 0.5))
        tail.closeSubpath()
        context.fill(tail, with: .color(.white.opacity(0.95)))

        context.draw(resolved, in: CGRect(
            x: bubble.minX + padding,
            y: bubble.minY + padding * 0.7,
            width: textSize.width,
            height: textSize.height
        ))
    }
}
