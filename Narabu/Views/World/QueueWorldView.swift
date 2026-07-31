import SwiftUI

/// 列に並んでいる世界そのもの。
///
/// 手前に後ろの人、中ほどに自分、その先に前の人が続き、
/// 奥は地平線まで人で埋まっている。景色は進むにつれて移り変わる。
struct QueueWorldView: View {
    let stage: Stage
    let anchorProgress: Int
    let anchorDate: Date
    /// 前の人に絡んだ直後に一瞬だけ姿勢を崩す。
    let disturbance: Double
    /// 前へ進んでいる最中だけ入る。
    let surge: Surge?
    /// 画面に別の吹き出しが出ているあいだは、前の人を黙らせる。
    let silencesRemark: Bool
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
        let progressExact = min(Double(stage.queueLength), Double(anchorProgress) + served)
        let time = date.timeIntervalSince1970
        // 進んでいる最中は、地平線が下がってカメラが前へ寄ったように見える。
        let push = surge?.cameraStrength(at: date) ?? 0
        let horizonY = size.height * (0.30 + push * 0.05)

        // 走っている最中は、進み終わった位置ではなく途中の位置を描く。
        // こうすると周りの人が後ろへ流れて、追い抜いたように見える。
        let remaining: Int
        let scroll: Double
        if let surge, !surge.isFinished(at: date) {
            remaining = surge.displayedRemaining(at: date)
            scroll = Double(stage.queueLength - remaining)
        } else {
            remaining = stage.queueLength - Int(progressExact)
            scroll = progressExact
        }
        let progress = stage.queueLength - remaining

        drawScenery(
            progress: progress,
            in: context,
            size: size,
            horizonY: horizonY,
            scroll: scroll,
            time: time
        )

        // 列の先にある店。進むほど大きくなり、何のために並んでいるかが常に見える。
        drawDestination(
            in: context,
            size: size,
            horizonY: horizonY,
            progress: progress,
            time: time
        )

        drawQueue(
            in: context,
            size: size,
            horizonY: horizonY,
            remaining: remaining,
            scene: stage.scene(atProgress: progress),
            time: time,
            date: date,
            push: push
        )

        if let surge, !surge.isFinished(at: date) {
            drawSurgeEffects(surge, in: context, size: size, date: date)
        }
    }

    // MARK: - 景色

    /// 場所が切り替わる境目では、前の景色に新しい景色を重ねて繋ぐ。
    ///
    /// 下地は必ず不透明で描く。以前は新しい景色を薄いまま描き始めていたため、
    /// 前の景色がない場面では何も描かれず、画面が真っ白になっていた。
    private func drawScenery(
        progress: Int,
        in context: GraphicsContext,
        size: CGSize,
        horizonY: Double,
        scroll: Double,
        time: Double
    ) {
        let scene = stage.scene(atProgress: progress)
        let blend = stage.sceneBlend(atProgress: progress)
        // 繋ぎの下地。前の景色がなければ、今の景色をそのまま下地にする。
        let base = stage.previousScene(atProgress: progress) ?? scene

        // 何があっても白い画面にならないよう、まず地の色で塗りつぶす。
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(base.skyColors.bottom)
        )

        SceneryRenderer.draw(
            kind: base,
            in: context,
            size: size,
            horizonY: horizonY,
            scroll: scroll,
            time: time
        )

        // 切り替わり中だけ、新しい景色を上から重ねていく。
        guard blend > 0, scene != base else { return }

        var layer = context
        layer.opacity = blend
        SceneryRenderer.draw(
            kind: scene,
            in: layer,
            size: size,
            horizonY: horizonY,
            scroll: scroll,
            time: time
        )
    }

    // MARK: - 列の先にある店

    /// 目的地を地平線に描く。
    ///
    /// 最初は遠くの点だが、進むほど大きくなる。
    /// 「何のために並んでいるのか」が、道の先にずっと見えている状態を作る。
    private func drawDestination(
        in context: GraphicsContext,
        size: CGSize,
        horizonY: Double,
        progress: Int,
        time: Double
    ) {
        let ratio = min(1, max(0, Double(progress) / Double(max(1, stage.queueLength))))
        // 遠近感に合わせて、近づくほど加速度的に大きく見える。
        let nearness = pow(ratio, 1.7)
        let width = size.width * (0.10 + nearness * 0.62)
        let height = size.height * (0.07 + nearness * 0.34)

        let rect = CGRect(
            x: size.width / 2 - width / 2,
            // 地平線より少し下に足元が来るようにして、道に立っているように見せる。
            y: horizonY + size.height * 0.02 - height,
            width: width,
            height: height
        )

        LandmarkRenderer.draw(
            stage: stage,
            in: context,
            rect: rect,
            // 遠いうちは影で、近づくと色がついてくる。
            silhouette: nearness < 0.12
        )

        drawApproachProps(in: context, size: size, horizonY: horizonY, nearness: nearness, time: time)
    }

    /// 店に近づくと、道の両脇に提灯とのぼりが増えてくる。
    private func drawApproachProps(
        in context: GraphicsContext,
        size: CGSize,
        horizonY: Double,
        nearness: Double,
        time: Double
    ) {
        guard nearness > 0.25 else { return }

        let intensity = min(1, (nearness - 0.25) / 0.6)
        let count = Int(intensity * 4) + 1

        for index in 0..<count {
            // 手前にあるものほど大きく、下に来る。
            let depth = Double(index) / Double(max(1, count))
            let y = horizonY + size.height * (0.03 + depth * 0.16)
            let scale = 0.35 + depth * 0.85
            let offset = size.width * (0.14 + depth * 0.2)
            let sway = sin(time * 1.4 + Double(index)) * size.width * 0.004

            for side in [-1.0, 1.0] {
                let x = size.width / 2 + side * offset + sway

                // 提灯
                let r = size.width * 0.035 * scale
                context.fill(
                    Path(ellipseIn: CGRect(x: x - r / 2, y: y, width: r, height: r * 1.3)),
                    with: .color(Color(red: 0.90, green: 0.25, blue: 0.18).opacity(0.9 * intensity))
                )
                // 灯り
                context.fill(
                    Path(ellipseIn: CGRect(x: x - r * 0.22, y: y + r * 0.35,
                                           width: r * 0.44, height: r * 0.5)),
                    with: .color(Color(red: 1.0, green: 0.88, blue: 0.55).opacity(0.75 * intensity))
                )

                // のぼり
                let poleHeight = size.width * 0.12 * scale
                context.fill(
                    Path(CGRect(x: x + side * r * 1.1, y: y, width: max(1, r * 0.12), height: poleHeight)),
                    with: .color(.white.opacity(0.5 * intensity))
                )
                context.fill(
                    Path(CGRect(x: x + side * r * 1.1, y: y + poleHeight * 0.1,
                                width: r * 0.5, height: poleHeight * 0.55)),
                    with: .color(Color(red: 0.86, green: 0.20, blue: 0.16).opacity(0.85 * intensity))
                )
            }
        }
    }

    // MARK: - 列

    private func drawQueue(
        in context: GraphicsContext,
        size: CGSize,
        horizonY: Double,
        remaining: Int,
        scene: SceneKind,
        time: Double,
        date: Date,
        push: Double
    ) {
        // 寄ったぶんだけ人が大きくなり、手前へ流れて見える。
        let baseY = size.height * (1.18 + push * 0.05)
        let centerX = size.width / 2
        let slotCount = Double(Self.behindCount + Self.aheadCount)

        // 進んでいるあいだは列から横に出る。抜いた人数が多いほど大きく回り込む。
        let sidestep = surge.map { run -> Double in
            let t = run.progress(at: date)
            guard t < 1 else { return 0 }
            // 出るのも戻るのも一瞬で、大半は横を進んでいる。
            let out = min(1, t / 0.16)
            let back = min(1, max(0, (1 - t) / 0.16))
            return min(out, back) * size.width * 0.30 * run.tier.cameraPush
        } ?? 0

        // 奥の人から描いて、手前の人が重なるようにする。
        for slot in stride(from: Self.aheadCount, through: -Self.behindCount, by: -1) {
            // 前進の直後だけ、列全体がわずかに手前へずれて追い越した感じが出る。
            let shifted = Double(slot) + Double(Self.behindCount) - push * 0.6
            let t = shifted / slotCount
            let depth = pow(max(t, 0), 0.42)
            let scale = pow(max(0, 1 - depth), 1.3)
            guard scale > 0.001 else { continue }

            let feetY = baseY - (baseY - horizonY) * depth
            let height = size.height * 0.52 * scale
            guard height > 3 else { continue }

            let isPlayer = slot == 0
            let queueIndex = remaining - slot
            guard queueIndex >= 0 else { continue }

            let person = isPlayer
                ? PersonFactory.player
                : PersonFactory.person(atQueueIndex: queueIndex, scene: scene)

            // 列はまっすぐではなく、少しずつ左右にずれて厚みが出る。
            let lateral = person.lateralOffset * size.width * 0.16 * scale
            let feet = CGPoint(
                x: centerX + lateral + (isPlayer ? sidestep : 0),
                y: feetY
            )
            let personHeight = height * person.heightScale

            let isSurging = surge.map { !$0.isFinished(at: date) } ?? false

            if isPlayer, !isSurging {
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

            if isPlayer, isSurging, let vehicle = surge?.vehicle {
                VehicleRenderer.draw(
                    vehicle,
                    in: context,
                    feet: feet,
                    height: personHeight,
                    time: time
                )
            }

            if isPlayer {
                drawPlayerLabel(in: context, feet: feet, height: personHeight, time: time)
            } else if slot == 1, !isSurging, !silencesRemark, !person.remark.isEmpty {
                drawRemark(person.remark, in: context, feet: feet, height: personHeight, size: size)
            }
        }
    }

    // MARK: - 前進の演出

    /// 抜いている最中の速度線と光。人数が多いほど激しくする。
    private func drawSurgeEffects(
        _ surge: Surge,
        in context: GraphicsContext,
        size: CGSize,
        date: Date
    ) {
        let t = surge.progress(at: date)
        // 走っている最中がいちばん強く、前後は控えめ。
        let intensity = sin(t * .pi)

        if surge.tier.showsSpeedLines {
            drawSpeedLines(in: context, size: size, date: date, intensity: intensity)
        }

        if surge.tier.flashes {
            // 走り出しの一瞬だけ、画面が白く飛ぶ。
            let flash = max(0, 1 - t / 0.18)
            if flash > 0 {
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(.white.opacity(flash * 0.65))
                )
            }
        }
    }

    /// 横に流れる線。速さを目で分からせる。
    private func drawSpeedLines(
        in context: GraphicsContext,
        size: CGSize,
        date: Date,
        intensity: Double
    ) {
        guard intensity > 0.05 else { return }
        let time = date.timeIntervalSince1970

        for index in 0..<16 {
            let y = QueueEngine.unitRandom(index, salt: 0xB77E) * size.height
            let length = size.width * (0.16 + QueueEngine.unitRandom(index, salt: 0xC88F) * 0.4)
            let offset = (time * 2_600 + Double(index) * 190)
                .truncatingRemainder(dividingBy: size.width + length)
            let x = size.width - offset

            context.fill(
                Path(CGRect(x: x, y: y, width: length, height: max(1.5, 3 * intensity))),
                with: .color(.white.opacity(0.5 * intensity))
            )
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

    /// 頭のすぐ上に小さな矢印だけを置く。
    ///
    /// 大きなラベルは前の人や吹き出しを隠してしまうので、印は控えめにして、
    /// 足元の光の輪と合わせて自分だとわかるようにする。
    private func drawPlayerLabel(
        in context: GraphicsContext,
        feet: CGPoint,
        height: Double,
        time: Double
    ) {
        let markerSize = height * 0.062
        let bob = sin(time * 2.4) * markerSize * 0.3
        let tipY = feet.y - height - markerSize * 0.5 + bob
        let marker = Color(red: 1.0, green: 0.84, blue: 0.28)

        var arrow = Path()
        arrow.move(to: CGPoint(x: feet.x - markerSize, y: tipY - markerSize * 1.5))
        arrow.addLine(to: CGPoint(x: feet.x + markerSize, y: tipY - markerSize * 1.5))
        arrow.addLine(to: CGPoint(x: feet.x, y: tipY))
        arrow.closeSubpath()

        // 背景が明るいところでも見えるように、細く縁取る。
        context.stroke(arrow, with: .color(.black.opacity(0.35)), lineWidth: 2)
        context.fill(arrow, with: .color(marker))
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
        // 人物の真上ではなく斜め上にずらして、顔と自分の印に重ならないようにする。
        let preferredX = feet.x + bubbleWidth * 0.4
        let centerX = min(max(preferredX, bubbleWidth / 2 + 8), size.width - bubbleWidth / 2 - 8)
        let bottomY = feet.y - height * 1.02

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
