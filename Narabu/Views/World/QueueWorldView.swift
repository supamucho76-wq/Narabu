import SwiftUI

/// 列に並んでいる世界そのもの。
///
/// 手前に後ろの人、中ほどに自分、その先に前の人が続き、
/// 奥は地平線まで人で埋まっている。景色は進むにつれて移り変わる。
/// ごぼう抜き中の状態。走っているあいだだけ存在する。
struct OvertakeRun: Equatable {
    let item: GachaItem
    /// 走り出したときの残り人数。
    let fromRemaining: Int
    /// 実際に追い抜く人数。
    let peopleSkipped: Int
    let startedAt: Date

    var duration: Double { item.overtakeDuration }

    /// 0 から 1 まで。終わったら 1 のまま。
    func progress(at date: Date) -> Double {
        min(1, max(0, date.timeIntervalSince(startedAt) / duration))
    }

    /// 走っている途中の見かけの残り人数。
    func displayedRemaining(at date: Date) -> Int {
        let eased = easeInOut(progress(at: date))
        return fromRemaining - Int((Double(peopleSkipped) * eased).rounded())
    }

    /// いま何人抜いたか。
    func countedSoFar(at date: Date) -> Int {
        Int((Double(peopleSkipped) * easeInOut(progress(at: date))).rounded())
    }

    /// 走り出しと止まりぎわをなめらかにする。
    private func easeInOut(_ t: Double) -> Double {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }
}

/// 前に進んだ直後の余韻。
///
/// 操作は止めずに、カメラだけが少し前へ寄って戻る。
/// これがないと、人数だけ変わって前に進んだ実感が出ない。
struct AdvancePulse: Equatable {
    let startedAt: Date
    /// 進んだ人数。多いほど寄りが強くなる。
    let people: Int

    static let duration: Double = 0.55

    /// 0から1へ。終わったら1のまま。
    func progress(at date: Date) -> Double {
        min(1, max(0, date.timeIntervalSince(startedAt) / Self.duration))
    }

    /// 寄り具合。ぐっと寄ってから、ゆっくり戻る。
    func strength(at date: Date) -> Double {
        let t = progress(at: date)
        guard t < 1 else { return 0 }
        let weight = min(1, Double(people) / 3)
        return sin(t * .pi) * weight
    }
}

struct QueueWorldView: View {
    let stage: Stage
    let anchorProgress: Int
    let anchorDate: Date
    /// 前の人に絡んだ直後に一瞬だけ姿勢を崩す。
    let disturbance: Double
    /// ごぼう抜き中だけ入る。
    let overtake: OvertakeRun?
    /// 直前に前進した時刻と人数。少しのあいだカメラが前に寄る。
    let advancePulse: AdvancePulse?
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
        // 前に進んだ直後は、地平線が下がってカメラが前へ寄ったように見える。
        let push = advancePulse?.strength(at: date) ?? 0
        let horizonY = size.height * (0.30 + push * 0.035)

        // 走っている最中は、追い抜き終わった位置ではなく途中の位置を描く。
        let remaining: Int
        let scroll: Double
        if let overtake {
            remaining = overtake.displayedRemaining(at: date)
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

        if let overtake {
            drawOvertakeCounter(overtake, in: context, size: size, date: date)
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

        // 走っているあいだは列から横に出る。
        let sidestep = overtake.map { run -> Double in
            let t = run.progress(at: date)
            // 出るのも戻るのも一瞬で、大半は横を走っている。
            let out = min(1, t / 0.14)
            let back = min(1, max(0, (1 - t) / 0.14))
            return min(out, back) * size.width * 0.30
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

            if isPlayer, overtake == nil {
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

            if isPlayer, let overtake {
                VehicleRenderer.draw(
                    overtake.item.vehicle,
                    in: context,
                    feet: feet,
                    height: personHeight,
                    time: time
                )
            }

            if isPlayer {
                drawPlayerLabel(in: context, feet: feet, height: personHeight, time: time)
            } else if slot == 1, overtake == nil, !silencesRemark, !person.remark.isEmpty {
                drawRemark(person.remark, in: context, feet: feet, height: personHeight, size: size)
            }
        }
    }

    // MARK: - ごぼう抜きのカウンター

    /// 走っているあいだ、抜いた人数が増えていくのを見せる。
    private func drawOvertakeCounter(
        _ run: OvertakeRun,
        in context: GraphicsContext,
        size: CGSize,
        date: Date
    ) {
        let counted = run.countedSoFar(at: date)
        let isDone = run.progress(at: date) >= 1
        let color = run.item.rarity.color

        let title = context.resolve(
            Text("\(counted)人抜き\(isDone ? "！" : "")")
                .font(.system(size: isDone ? 46 : 38, weight: .black, design: .rounded))
                .foregroundColor(.white)
        )
        let center = CGPoint(x: size.width / 2, y: size.height * 0.2)

        // 読めるように後ろに影を敷く。
        let measured = title.measure(in: size)
        context.fill(
            Path(roundedRect: CGRect(
                x: center.x - measured.width / 2 - 20,
                y: center.y - measured.height / 2 - 10,
                width: measured.width + 40,
                height: measured.height + 20
            ), cornerRadius: 12),
            with: .color(color.opacity(0.85))
        )
        context.draw(title, at: center)

        context.draw(
            Text(run.item.name)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white),
            at: CGPoint(x: center.x, y: center.y + measured.height / 2 + 22)
        )
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
