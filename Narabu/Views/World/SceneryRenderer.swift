import SwiftUI

/// 列が通っている場所を描く。
///
/// 道は地平線に向かって細くなり、路面の目地と両脇のものが手前に流れてくる。
/// 列は止まっているように見えても、景色が動くことで歩いている感じになる。
enum SceneryRenderer {
    /// 道の両脇に置くものの数。
    private static let propCount = 13
    /// 路面の目地の本数。
    private static let stripeCount = 16

    static func draw(
        kind: SceneKind,
        in context: GraphicsContext,
        size: CGSize,
        horizonY: Double,
        scroll: Double,
        time: Double
    ) {
        drawSky(kind: kind, in: context, size: size, horizonY: horizonY, time: time)
        drawGround(kind: kind, in: context, size: size, horizonY: horizonY)
        drawPath(kind: kind, in: context, size: size, horizonY: horizonY, scroll: scroll)
        drawProps(kind: kind, in: context, size: size, horizonY: horizonY, scroll: scroll)
        drawWeatherOverlay(kind: kind, in: context, size: size, time: time)
    }

    // MARK: - 空と地面

    private static func drawSky(
        kind: SceneKind,
        in context: GraphicsContext,
        size: CGSize,
        horizonY: Double,
        time: Double
    ) {
        let colors = kind.skyColors
        context.fill(
            Path(CGRect(x: 0, y: 0, width: size.width, height: horizonY + 1)),
            with: .linearGradient(
                Gradient(colors: [colors.top, colors.bottom]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: horizonY)
            )
        )

        switch kind {
        case .space:
            drawStars(in: context, size: size, horizonY: horizonY, time: time)
        case .heaven:
            drawClouds(in: context, size: size, horizonY: horizonY, time: time)
        case .desert:
            drawSun(in: context, size: size, horizonY: horizonY)
        default:
            break
        }
    }

    private static func drawGround(
        kind: SceneKind,
        in context: GraphicsContext,
        size: CGSize,
        horizonY: Double
    ) {
        let ground = kind.groundColor
        context.fill(
            Path(CGRect(x: 0, y: horizonY, width: size.width, height: size.height - horizonY)),
            with: .linearGradient(
                Gradient(colors: [ground.opacity(0.7), ground]),
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
        let bottomHalf = size.width * 0.60
        let topHalf = size.width * 0.03

        var path = Path()
        path.move(to: CGPoint(x: centerX - topHalf, y: horizonY))
        path.addLine(to: CGPoint(x: centerX + topHalf, y: horizonY))
        path.addLine(to: CGPoint(x: centerX + bottomHalf, y: size.height))
        path.addLine(to: CGPoint(x: centerX - bottomHalf, y: size.height))
        path.closeSubpath()

        // 海や宇宙では足場がはっきり見えたほうが列らしくなる。
        let deck: Color = switch kind {
        case .sea: Color(red: 0.70, green: 0.58, blue: 0.42)
        case .space: Color(red: 0.36, green: 0.34, blue: 0.48)
        case .heaven: Color(red: 0.98, green: 0.96, blue: 0.88)
        default: kind.groundColor.opacity(0.5)
        }
        context.fill(path, with: .color(deck))

        // 路面の目地。手前ほど間隔が広く、下に流れていく。
        var stripes = context
        stripes.clip(to: path)

        let offset = scroll - scroll.rounded(.down)
        for index in 0..<stripeCount {
            let z = Double(index) + 1 - offset
            let t = depthFactor(z)
            let y = horizonY + (size.height - horizonY) * t
            let half = topHalf + (bottomHalf - topHalf) * t

            stripes.fill(
                Path(CGRect(x: centerX - half, y: y, width: half * 2, height: max(0.6, 3.4 * t))),
                with: .color(.black.opacity(0.10 * t + 0.03))
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
        let bottomHalf = size.width * 0.60
        let topHalf = size.width * 0.03
        let offset = scroll - scroll.rounded(.down)

        // 奥のものから描いて、手前のもので隠す。
        for index in stride(from: propCount, through: 0, by: -1) {
            let z = Double(index) * 1.7 + 0.9 - offset * 1.7
            guard z > 0.05 else { continue }

            let t = depthFactor(z)
            let baseY = horizonY + (size.height - horizonY) * t
            let half = topHalf + (bottomHalf - topHalf) * t

            for side in [-1.0, 1.0] {
                let x = centerX + side * (half + size.width * 0.13 * t)
                drawProp(
                    kind: kind,
                    in: context,
                    x: x,
                    baseY: baseY,
                    scale: t,
                    size: size,
                    seed: index &* 31 &+ Int(side)
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
            let w = unit * 0.32
            let h = unit * (0.30 + variation * 0.16)
            let body = CGRect(x: x - w / 2, y: baseY - h, width: w, height: h)
            context.fill(Path(body), with: .color(color))

            var roof = Path()
            roof.move(to: CGPoint(x: body.minX - w * 0.12, y: body.minY))
            roof.addLine(to: CGPoint(x: body.midX, y: body.minY - h * 0.45))
            roof.addLine(to: CGPoint(x: body.maxX + w * 0.12, y: body.minY))
            roof.closeSubpath()
            context.fill(roof, with: .color(Color(red: 0.46, green: 0.34, blue: 0.30)))
            drawWindows(in: context, rect: body, rows: 2, columns: 2, scale: scale, lit: true)

        case .shopping:
            let w = unit * 0.36
            let h = unit * (0.26 + variation * 0.14)
            let body = CGRect(x: x - w / 2, y: baseY - h, width: w, height: h)
            context.fill(Path(body), with: .color(color))

            let awning = CGRect(x: body.minX - w * 0.1, y: body.minY + h * 0.4, width: w * 1.2, height: h * 0.18)
            context.fill(Path(awning), with: .color(Color(red: 0.90, green: 0.76, blue: 0.34)))
            drawWindows(in: context, rect: body, rows: 1, columns: 3, scale: scale, lit: true)

        case .forest:
            drawTree(in: context, x: x, baseY: baseY, unit: unit, variation: variation, color: color)

        case .sea:
            // 波と、ときどき浮かぶ浮き輪
            let w = unit * 0.5
            let wave = CGRect(x: x - w / 2, y: baseY - unit * 0.02, width: w, height: unit * 0.05)
            context.fill(Path(ellipseIn: wave), with: .color(color.opacity(0.5)))
            if variation > 0.72 {
                let r = unit * 0.09
                context.stroke(
                    Path(ellipseIn: CGRect(x: x - r / 2, y: baseY - r * 0.6, width: r, height: r * 0.5)),
                    with: .color(Color(red: 0.90, green: 0.36, blue: 0.30)),
                    lineWidth: max(1, unit * 0.02)
                )
            }

        case .snow:
            drawTree(in: context, x: x, baseY: baseY, unit: unit, variation: variation,
                     color: Color(red: 0.22, green: 0.34, blue: 0.28), snowy: true)
            let moundW = unit * 0.3
            context.fill(
                Path(ellipseIn: CGRect(x: x - moundW / 2, y: baseY - moundW * 0.16,
                                       width: moundW, height: moundW * 0.34)),
                with: .color(.white.opacity(0.9))
            )

        case .desert:
            // サボテン
            let w = unit * 0.07
            let h = unit * (0.24 + variation * 0.18)
            context.fill(
                Path(roundedRect: CGRect(x: x - w / 2, y: baseY - h, width: w, height: h),
                     cornerRadius: w * 0.5),
                with: .color(color)
            )
            let armH = h * 0.4
            context.fill(
                Path(roundedRect: CGRect(x: x + w * 0.4, y: baseY - h * 0.75, width: w * 0.7, height: armH),
                     cornerRadius: w * 0.35),
                with: .color(color)
            )

        case .space:
            // 浮いている岩
            let w = unit * (0.12 + variation * 0.14)
            let float = sin(Double(seed) + baseY * 0.01) * unit * 0.05
            context.fill(
                Path(ellipseIn: CGRect(x: x - w / 2, y: baseY - w * 1.4 + float, width: w, height: w * 0.7)),
                with: .color(color)
            )

        case .hell:
            // 岩と炎
            let w = unit * 0.16
            let h = unit * (0.2 + variation * 0.16)
            var rock = Path()
            rock.move(to: CGPoint(x: x - w / 2, y: baseY))
            rock.addLine(to: CGPoint(x: x, y: baseY - h))
            rock.addLine(to: CGPoint(x: x + w / 2, y: baseY))
            rock.closeSubpath()
            context.fill(rock, with: .color(color))

            let flameH = unit * 0.12
            context.fill(
                Path(ellipseIn: CGRect(x: x - w * 0.2, y: baseY - h - flameH * 0.6,
                                       width: w * 0.4, height: flameH)),
                with: .color(Color(red: 0.98, green: 0.56, blue: 0.14).opacity(0.85))
            )

        case .heaven:
            // 柱と雲
            let w = unit * 0.1
            let h = unit * (0.4 + variation * 0.2)
            context.fill(
                Path(roundedRect: CGRect(x: x - w / 2, y: baseY - h, width: w, height: h),
                     cornerRadius: w * 0.2),
                with: .color(color)
            )
            let cloudW = unit * 0.3
            context.fill(
                Path(ellipseIn: CGRect(x: x - cloudW / 2, y: baseY - cloudW * 0.16,
                                       width: cloudW, height: cloudW * 0.34)),
                with: .color(.white.opacity(0.8))
            )

        case .ramen:
            // 赤い提灯とのぼり
            let w = unit * 0.1
            let h = unit * 0.3
            context.fill(
                Path(roundedRect: CGRect(x: x - w / 2, y: baseY - h, width: w, height: h * 0.5),
                     cornerRadius: w * 0.4),
                with: .color(color)
            )
        }
    }

    private static func drawTree(
        in context: GraphicsContext,
        x: Double,
        baseY: Double,
        unit: Double,
        variation: Double,
        color: Color,
        snowy: Bool = false
    ) {
        let trunkW = unit * 0.05
        let treeH = unit * (0.44 + variation * 0.3)
        context.fill(
            Path(CGRect(x: x - trunkW / 2, y: baseY - treeH * 0.4, width: trunkW, height: treeH * 0.4)),
            with: .color(Color(red: 0.32, green: 0.24, blue: 0.18))
        )

        for layer in 0..<3 {
            let layerT = Double(layer)
            let leafW = unit * (0.32 - layerT * 0.07)
            let leafY = baseY - treeH * (0.4 + layerT * 0.24)
            let rect = CGRect(x: x - leafW / 2, y: leafY - leafW * 0.62, width: leafW, height: leafW * 0.95)
            context.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.92 - layerT * 0.06)))

            if snowy {
                let capRect = CGRect(x: rect.minX, y: rect.minY, width: leafW, height: leafW * 0.4)
                context.fill(Path(ellipseIn: capRect), with: .color(.white.opacity(0.85)))
            }
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
        guard scale > 0.14 else { return }

        let padX = rect.width * 0.16
        let padY = rect.height * 0.14
        let cellW = (rect.width - padX * 2) / Double(columns)
        let cellH = (rect.height - padY * 2) / Double(rows)

        for row in 0..<rows {
            for column in 0..<columns {
                let seed = row &* 17 &+ column &* 7 &+ Int(rect.minX)
                let isLit = lit && QueueEngine.unitRandom(seed, salt: 0x77C1) > 0.4
                let window = CGRect(
                    x: rect.minX + padX + Double(column) * cellW + cellW * 0.18,
                    y: rect.minY + padY + Double(row) * cellH + cellH * 0.16,
                    width: cellW * 0.64,
                    height: cellH * 0.62
                )
                context.fill(
                    Path(window),
                    with: .color(isLit
                        ? Color(red: 0.99, green: 0.90, blue: 0.64).opacity(0.92)
                        : .black.opacity(0.3))
                )
            }
        }
    }

    // MARK: - 空の飾りと天気

    private static func drawStars(in context: GraphicsContext, size: CGSize, horizonY: Double, time: Double) {
        for index in 0..<90 {
            let x = QueueEngine.unitRandom(index, salt: 0x3D92) * size.width
            let y = QueueEngine.unitRandom(index, salt: 0x4EA3) * horizonY
            let twinkle = 0.4 + 0.6 * abs(sin(time * 0.6 + Double(index)))
            let r = 0.8 + QueueEngine.unitRandom(index, salt: 0x5FB4) * 1.8

            context.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                with: .color(.white.opacity(twinkle))
            )
        }
    }

    private static func drawClouds(in context: GraphicsContext, size: CGSize, horizonY: Double, time: Double) {
        for index in 0..<8 {
            let w = size.width * (0.2 + QueueEngine.unitRandom(index, salt: 0x6AC1) * 0.3)
            let drift = time * 4 * (0.5 + QueueEngine.unitRandom(index, salt: 0x7BD2))
            let x = (QueueEngine.unitRandom(index, salt: 0x8CE3) * size.width + drift)
                .truncatingRemainder(dividingBy: size.width + w) - w / 2
            let y = QueueEngine.unitRandom(index, salt: 0x9DF4) * horizonY * 0.8

            context.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: w, height: w * 0.26)),
                with: .color(.white.opacity(0.7))
            )
        }
    }

    private static func drawSun(in context: GraphicsContext, size: CGSize, horizonY: Double) {
        let r = size.width * 0.16
        context.fill(
            Path(ellipseIn: CGRect(x: size.width * 0.68, y: horizonY * 0.24, width: r, height: r)),
            with: .color(Color(red: 1.0, green: 0.94, blue: 0.72).opacity(0.9))
        )
    }

    private static func drawWeatherOverlay(
        kind: SceneKind,
        in context: GraphicsContext,
        size: CGSize,
        time: Double
    ) {
        switch kind {
        case .snow:
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

        case .hell:
            // 舞い上がる火の粉
            for index in 0..<40 {
                let speed = 26 + QueueEngine.unitRandom(index, salt: 0xA1B2) * 40
                let x = QueueEngine.unitRandom(index, salt: 0xB2C3) * size.width
                    + sin(time + Double(index)) * 10
                let y = size.height - (QueueEngine.unitRandom(index, salt: 0xC3D4) * size.height + time * speed)
                    .truncatingRemainder(dividingBy: size.height)
                let r = 1.0 + QueueEngine.unitRandom(index, salt: 0xD4E5) * 2.0
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                    with: .color(Color(red: 1.0, green: 0.62, blue: 0.22).opacity(0.8))
                )
            }

        default:
            break
        }
    }
}
