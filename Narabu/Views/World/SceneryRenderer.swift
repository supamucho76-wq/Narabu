import SwiftUI

/// 列が通っている場所を描く。
///
/// 道は地平線に向かって細くなり、路面の目地と両脇のものが手前に流れてくる。
/// 列は止まっているように見えても、景色が動くことで歩いている感じになる。
enum SceneryRenderer {
    /// 道の両脇に置くものの数。
    private static let propCount = 14
    /// 路面の目地の本数。
    private static let stripeCount = 18

    static func draw(
        kind: SceneKind,
        in context: GraphicsContext,
        size: CGSize,
        horizonY: Double,
        scroll: Double,
        time: Double
    ) {
        drawSky(kind: kind, in: context, size: size, horizonY: horizonY)
        drawGround(kind: kind, in: context, size: size, horizonY: horizonY)
        drawPath(kind: kind, in: context, size: size, horizonY: horizonY, scroll: scroll)
        drawProps(kind: kind, in: context, size: size, horizonY: horizonY, scroll: scroll)

        if kind == .snow {
            drawSnowfall(in: context, size: size, time: time)
        }
        if kind == .reception {
            drawReception(in: context, size: size, horizonY: horizonY)
        }
    }

    // MARK: - 空と地面

    private static func drawSky(kind: SceneKind, in context: GraphicsContext, size: CGSize, horizonY: Double) {
        let colors = kind.skyColors
        context.fill(
            Path(CGRect(x: 0, y: 0, width: size.width, height: horizonY + 1)),
            with: .linearGradient(
                Gradient(colors: [colors.top, colors.bottom]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: horizonY)
            )
        )
    }

    private static func drawGround(kind: SceneKind, in context: GraphicsContext, size: CGSize, horizonY: Double) {
        let ground = kind.groundColor
        context.fill(
            Path(CGRect(x: 0, y: horizonY, width: size.width, height: size.height - horizonY)),
            with: .linearGradient(
                Gradient(colors: [ground.opacity(0.75), ground]),
                startPoint: CGPoint(x: 0, y: horizonY),
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )
    }

    // MARK: - 道

    private static func drawPath(
        kind: SceneKind,
        in context: GraphicsContext,
        size: CGSize,
        horizonY: Double,
        scroll: Double
    ) {
        let centerX = size.width / 2
        let bottomHalf = size.width * 0.46
        let topHalf = size.width * 0.02

        var path = Path()
        path.move(to: CGPoint(x: centerX - topHalf, y: horizonY))
        path.addLine(to: CGPoint(x: centerX + topHalf, y: horizonY))
        path.addLine(to: CGPoint(x: centerX + bottomHalf, y: size.height))
        path.addLine(to: CGPoint(x: centerX - bottomHalf, y: size.height))
        path.closeSubpath()

        context.fill(path, with: .color(kind.groundColor.opacity(0.45)))

        // 路面の目地。手前ほど間隔が広く、下に流れていく。
        var stripes = context
        stripes.clip(to: path)

        let offset = scroll - scroll.rounded(.down)
        for index in 0..<stripeCount {
            let z = Double(index) + 1 - offset
            let t = depthFactor(z)
            let y = horizonY + (size.height - horizonY) * t
            let half = topHalf + (bottomHalf - topHalf) * t
            let thickness = max(0.6, 3.2 * t)

            stripes.fill(
                Path(CGRect(x: centerX - half, y: y, width: half * 2, height: thickness)),
                with: .color(Color.black.opacity(0.10 * t + 0.02))
            )
        }
    }

    /// 奥行き z を、地平線 0 から手前 1 の位置に写す。
    private static func depthFactor(_ z: Double) -> Double {
        1 / (1 + max(z, 0.001) * 0.42)
    }

    // MARK: - 道の両脇

    private static func drawProps(
        kind: SceneKind,
        in context: GraphicsContext,
        size: CGSize,
        horizonY: Double,
        scroll: Double
    ) {
        let centerX = size.width / 2
        let bottomHalf = size.width * 0.46
        let topHalf = size.width * 0.02
        let offset = scroll - scroll.rounded(.down)

        // 奥のものから描いて、手前のもので隠す。
        for index in stride(from: propCount, through: 0, by: -1) {
            let z = Double(index) * 1.6 + 0.8 - offset * 1.6
            guard z > 0.05 else { continue }

            let t = depthFactor(z)
            let baseY = horizonY + (size.height - horizonY) * t
            let half = topHalf + (bottomHalf - topHalf) * t
            let scale = t

            for side in [-1.0, 1.0] {
                let seed = index &* 31 &+ Int(side)
                let x = centerX + side * (half + size.width * 0.10 * scale)
                drawProp(
                    kind: kind,
                    in: context,
                    x: x,
                    baseY: baseY,
                    scale: scale,
                    size: size,
                    seed: seed
                )
            }
        }
    }

    private static func drawProp(
        kind: SceneKind,
        in context: GraphicsContext,
        x: Double,
        baseY: Double,
        scale: Double,
        size: CGSize,
        seed: Int
    ) {
        let unit = size.height * scale
        let variation = QueueEngine.unitRandom(seed, salt: 0x1F0D)
        let color = kind.propColor

        switch kind {
        case .residential:
            let w = unit * 0.30
            let h = unit * (0.28 + variation * 0.14)
            let body = CGRect(x: x - w / 2, y: baseY - h, width: w, height: h)
            context.fill(Path(body), with: .color(color))

            var roof = Path()
            roof.move(to: CGPoint(x: body.minX - w * 0.1, y: body.minY))
            roof.addLine(to: CGPoint(x: body.midX, y: body.minY - h * 0.42))
            roof.addLine(to: CGPoint(x: body.maxX + w * 0.1, y: body.minY))
            roof.closeSubpath()
            context.fill(roof, with: .color(color.opacity(0.72)))
            drawWindows(in: context, rect: body, rows: 2, columns: 2, scale: scale)

        case .shopping:
            let w = unit * 0.34
            let h = unit * (0.24 + variation * 0.12)
            let body = CGRect(x: x - w / 2, y: baseY - h, width: w, height: h)
            context.fill(Path(body), with: .color(color.opacity(0.9)))

            // 日よけ
            let awning = CGRect(x: body.minX - w * 0.08, y: body.minY + h * 0.42, width: w * 1.16, height: h * 0.16)
            context.fill(Path(awning), with: .color(Color(red: 0.86, green: 0.72, blue: 0.36)))
            drawWindows(in: context, rect: body, rows: 1, columns: 3, scale: scale)

        case .forest:
            let trunkW = unit * 0.045
            let treeH = unit * (0.40 + variation * 0.26)
            let trunk = CGRect(x: x - trunkW / 2, y: baseY - treeH * 0.45, width: trunkW, height: treeH * 0.45)
            context.fill(Path(trunk), with: .color(Color(red: 0.32, green: 0.24, blue: 0.18)))

            for layer in 0..<3 {
                let layerT = Double(layer)
                let leafW = unit * (0.28 - layerT * 0.06)
                let leafY = baseY - treeH * (0.45 + layerT * 0.22)
                let leaf = CGRect(x: x - leafW / 2, y: leafY - leafW * 0.6, width: leafW, height: leafW * 0.9)
                context.fill(Path(ellipseIn: leaf), with: .color(color.opacity(0.9 - layerT * 0.08)))
            }

        case .snow:
            let trunkW = unit * 0.035
            let treeH = unit * (0.34 + variation * 0.2)
            let trunk = CGRect(x: x - trunkW / 2, y: baseY - treeH, width: trunkW, height: treeH)
            context.fill(Path(trunk), with: .color(Color(red: 0.34, green: 0.30, blue: 0.30)))

            let capW = unit * 0.2
            let cap = CGRect(x: x - capW / 2, y: baseY - treeH - capW * 0.3, width: capW, height: capW * 0.6)
            context.fill(Path(ellipseIn: cap), with: .color(color))

            let moundW = unit * 0.26
            let mound = CGRect(x: x - moundW / 2, y: baseY - moundW * 0.18, width: moundW, height: moundW * 0.36)
            context.fill(Path(ellipseIn: mound), with: .color(Color.white.opacity(0.85)))

        case .hotel:
            let w = unit * 0.28
            let h = unit * (0.7 + variation * 0.5)
            let body = CGRect(x: x - w / 2, y: baseY - h, width: w, height: h)
            context.fill(Path(body), with: .color(color))
            drawWindows(in: context, rect: body, rows: 7, columns: 3, scale: scale, lit: true)

        case .palace:
            let w = unit * 0.16
            let h = unit * (0.6 + variation * 0.2)
            let column = CGRect(x: x - w / 2, y: baseY - h, width: w, height: h)
            context.fill(
                Path(roundedRect: column, cornerRadius: w * 0.2),
                with: .color(color)
            )
            let capital = CGRect(x: column.minX - w * 0.2, y: column.minY, width: w * 1.4, height: h * 0.08)
            context.fill(Path(capital), with: .color(color.opacity(0.8)))

        case .reception:
            let w = unit * 0.3
            let h = unit * 0.9
            let wall = CGRect(x: x - w / 2, y: baseY - h, width: w, height: h)
            context.fill(Path(wall), with: .color(color))
        }
    }

    private static func drawWindows(
        in context: GraphicsContext,
        rect: CGRect,
        rows: Int,
        columns: Int,
        scale: Double,
        lit: Bool = false
    ) {
        guard scale > 0.16 else { return }

        let padX = rect.width * 0.16
        let padY = rect.height * 0.14
        let cellW = (rect.width - padX * 2) / Double(columns)
        let cellH = (rect.height - padY * 2) / Double(rows)

        for row in 0..<rows {
            for column in 0..<columns {
                let seed = row &* 17 &+ column &* 7 &+ Int(rect.minX)
                let isLit = lit && QueueEngine.unitRandom(seed, salt: 0x77C1) > 0.45
                let window = CGRect(
                    x: rect.minX + padX + Double(column) * cellW + cellW * 0.18,
                    y: rect.minY + padY + Double(row) * cellH + cellH * 0.16,
                    width: cellW * 0.64,
                    height: cellH * 0.62
                )
                context.fill(
                    Path(window),
                    with: .color(isLit
                        ? Color(red: 0.98, green: 0.88, blue: 0.62).opacity(0.9)
                        : Color.black.opacity(0.28))
                )
            }
        }
    }

    // MARK: - 天気と建物

    private static func drawSnowfall(in context: GraphicsContext, size: CGSize, time: Double) {
        for index in 0..<70 {
            let speed = 18 + QueueEngine.unitRandom(index, salt: 0x2C81) * 30
            let drift = sin(time * 0.6 + Double(index)) * 12
            let x = QueueEngine.unitRandom(index, salt: 0x3D92) * size.width + drift
            let y = (QueueEngine.unitRandom(index, salt: 0x4EA3) * size.height + time * speed)
                .truncatingRemainder(dividingBy: size.height)
            let r = 1.2 + QueueEngine.unitRandom(index, salt: 0x5FB4) * 2.2

            context.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                with: .color(.white.opacity(0.85))
            )
        }
    }

    /// 列の先にある受付。近づくと窓口の明かりが見える。
    private static func drawReception(in context: GraphicsContext, size: CGSize, horizonY: Double) {
        let w = size.width * 0.34
        let h = size.height * 0.2
        let rect = CGRect(x: size.width / 2 - w / 2, y: horizonY - h * 0.2, width: w, height: h)
        context.fill(
            Path(roundedRect: rect, cornerRadius: w * 0.05),
            with: .color(Color(red: 0.24, green: 0.22, blue: 0.24))
        )

        let window = CGRect(
            x: rect.midX - w * 0.3,
            y: rect.midY - h * 0.22,
            width: w * 0.6,
            height: h * 0.42
        )
        context.fill(
            Path(window),
            with: .color(Color(red: 0.98, green: 0.90, blue: 0.68))
        )
    }
}
