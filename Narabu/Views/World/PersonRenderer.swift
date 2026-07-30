import SwiftUI

/// 列に並んでいる人を後ろから描く。
///
/// 遠くの人は小さく薄くなるだけで、描きかたは手前の人と同じ。
/// 近づくにつれて持ち物や髪型が見分けられるようになる。
enum PersonRenderer {
    /// - Parameters:
    ///   - feet: 足元の位置。
    ///   - height: 頭のてっぺんから足元までの高さ。
    ///   - fade: 遠くの人ほど景色に溶ける度合い。1 がはっきり見える状態。
    static func draw(
        _ person: QueuePerson,
        in context: GraphicsContext,
        feet: CGPoint,
        height: Double,
        time: Double,
        fade: Double
    ) {
        guard height > 3 else { return }

        var canvas = context
        // 亡霊は向こう側が透けて見える。
        canvas.opacity = fade * (person.type == .ghost ? 0.55 : 1)

        // 遠くの人は輪郭しか見えないので、髪型や持ち物は描かない。
        let showsDetail = height > 20

        let sway = sin(time * 0.8 + person.swayPhase) * height * 0.006
        let x = feet.x + sway
        let bottomY = feet.y

        let headDiameter = height * 0.17
        let headTop = bottomY - height
        let shoulderY = headTop + headDiameter * 1.08
        let hipY = bottomY - height * 0.46
        let torsoWidth = height * 0.26 * person.build
        let legWidth = torsoWidth * 0.40
        let armWidth = torsoWidth * 0.22

        if showsDetail {
            drawGroundItem(person, in: canvas, x: x, bottomY: bottomY, height: height, time: time)
        }

        // 脚
        let stride = sin(time * 0.8 + person.swayPhase) * height * 0.012
        for side in [-1.0, 1.0] {
            let legX = x + side * (torsoWidth * 0.22) - legWidth / 2
            let legTop = hipY - height * 0.02
            let rect = CGRect(
                x: legX,
                y: legTop,
                width: legWidth,
                height: bottomY - legTop + side * stride
            )
            canvas.fill(
                Path(roundedRect: rect, cornerRadius: legWidth * 0.42),
                with: .color(person.bottom)
            )
        }

        // 胴体
        let torso = CGRect(
            x: x - torsoWidth / 2,
            y: shoulderY,
            width: torsoWidth,
            height: hipY - shoulderY + height * 0.03
        )
        canvas.fill(
            Path(roundedRect: torso, cornerSize: CGSize(width: torsoWidth * 0.3, height: torsoWidth * 0.3)),
            with: .color(person.top)
        )

        if showsDetail {
            drawArms(
                person,
                in: canvas,
                x: x,
                shoulderY: shoulderY,
                hipY: hipY,
                torsoWidth: torsoWidth,
                armWidth: armWidth,
                height: height
            )
        }

        // 頭
        let headRect = CGRect(
            x: x - headDiameter / 2,
            y: headTop,
            width: headDiameter,
            height: headDiameter * 1.08
        )
        canvas.fill(Path(ellipseIn: headRect), with: .color(person.skin))

        guard showsDetail else { return }

        if person.type == .ordinary {
            drawHair(person, in: canvas, headRect: headRect)
        } else {
            drawTypeFeatures(person, in: canvas, headRect: headRect, torsoRect: torso, height: height)
        }
        drawHeldItem(person, in: canvas, x: x, shoulderY: shoulderY, height: height, torsoWidth: torsoWidth)
    }

    // MARK: - 種類ごとの特徴

    /// 宇宙人の触角、武士のちょんまげ、天使の輪など、その種類だとわかる部分。
    private static func drawTypeFeatures(
        _ person: QueuePerson,
        in context: GraphicsContext,
        headRect: CGRect,
        torsoRect: CGRect,
        height: Double
    ) {
        let w = headRect.width

        switch person.type {
        case .ordinary:
            break

        case .suit:
            drawHair(person, in: context, headRect: headRect)
            // 襟
            var collar = Path()
            collar.move(to: CGPoint(x: torsoRect.midX - w * 0.3, y: torsoRect.minY))
            collar.addLine(to: CGPoint(x: torsoRect.midX, y: torsoRect.minY + height * 0.06))
            collar.addLine(to: CGPoint(x: torsoRect.midX + w * 0.3, y: torsoRect.minY))
            collar.closeSubpath()
            context.fill(collar, with: .color(.white.opacity(0.85)))

        case .baby:
            drawHair(person, in: context, headRect: headRect)
            // 頭の上の一本毛
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: headRect.midX, y: headRect.minY))
                    path.addQuadCurve(
                        to: CGPoint(x: headRect.midX + w * 0.24, y: headRect.minY - w * 0.34),
                        control: CGPoint(x: headRect.midX + w * 0.3, y: headRect.minY - w * 0.06)
                    )
                },
                with: .color(person.hair),
                lineWidth: max(1, w * 0.09)
            )

        case .samurai:
            let cap = CGRect(x: headRect.minX, y: headRect.minY, width: w, height: headRect.height * 0.55)
            context.fill(
                Path(roundedRect: cap, cornerSize: CGSize(width: w * 0.5, height: w * 0.4)),
                with: .color(person.hair)
            )
            // ちょんまげ
            context.fill(
                Path(roundedRect: CGRect(x: headRect.midX - w * 0.09, y: headRect.minY - w * 0.28,
                                         width: w * 0.18, height: w * 0.34),
                     cornerRadius: w * 0.09),
                with: .color(person.hair)
            )

        case .alien:
            // 触角
            for side in [-1.0, 1.0] {
                let baseX = headRect.midX + side * w * 0.22
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: baseX, y: headRect.minY + w * 0.1))
                        path.addLine(to: CGPoint(x: baseX + side * w * 0.16, y: headRect.minY - w * 0.36))
                    },
                    with: .color(person.skin),
                    lineWidth: max(1, w * 0.07)
                )
                context.fill(
                    Path(ellipseIn: CGRect(x: baseX + side * w * 0.16 - w * 0.08,
                                           y: headRect.minY - w * 0.44,
                                           width: w * 0.16, height: w * 0.16)),
                    with: .color(person.accent)
                )
            }

        case .mascot:
            // まるい耳
            for side in [-1.0, 1.0] {
                context.fill(
                    Path(ellipseIn: CGRect(x: headRect.midX + side * w * 0.42 - w * 0.2,
                                           y: headRect.minY - w * 0.1,
                                           width: w * 0.4, height: w * 0.4)),
                    with: .color(person.skin)
                )
            }

        case .santa:
            let hat = CGRect(x: headRect.minX - w * 0.06, y: headRect.minY - w * 0.1,
                             width: w * 1.12, height: headRect.height * 0.5)
            context.fill(
                Path(roundedRect: hat, cornerSize: CGSize(width: w * 0.4, height: w * 0.36)),
                with: .color(Color(red: 0.82, green: 0.16, blue: 0.16))
            )
            context.fill(
                Path(ellipseIn: CGRect(x: headRect.midX + w * 0.3, y: headRect.minY - w * 0.3,
                                       width: w * 0.24, height: w * 0.24)),
                with: .color(.white)
            )
            // ひげ
            context.fill(
                Path(ellipseIn: CGRect(x: headRect.minX, y: headRect.maxY - w * 0.28,
                                       width: w, height: w * 0.44)),
                with: .color(.white.opacity(0.95))
            )

        case .maid:
            drawHair(person, in: context, headRect: headRect)
            // ヘッドドレス
            context.fill(
                Path(roundedRect: CGRect(x: headRect.minX + w * 0.1, y: headRect.minY - w * 0.06,
                                         width: w * 0.8, height: w * 0.16),
                     cornerRadius: w * 0.08),
                with: .color(.white)
            )
            // エプロン
            context.fill(
                Path(CGRect(x: torsoRect.midX - torsoRect.width * 0.28, y: torsoRect.midY,
                            width: torsoRect.width * 0.56, height: torsoRect.height * 0.5)),
                with: .color(.white.opacity(0.9))
            )

        case .sumo:
            // まわし
            context.fill(
                Path(CGRect(x: torsoRect.minX, y: torsoRect.maxY - torsoRect.height * 0.22,
                            width: torsoRect.width, height: torsoRect.height * 0.24)),
                with: .color(person.bottom)
            )
            context.fill(
                Path(roundedRect: CGRect(x: headRect.midX - w * 0.1, y: headRect.minY - w * 0.2,
                                         width: w * 0.2, height: w * 0.3),
                     cornerRadius: w * 0.1),
                with: .color(person.hair)
            )

        case .ghost:
            break

        case .angel:
            // 光の輪
            context.stroke(
                Path(ellipseIn: CGRect(x: headRect.midX - w * 0.42, y: headRect.minY - w * 0.46,
                                       width: w * 0.84, height: w * 0.28)),
                with: .color(Color(red: 1.0, green: 0.92, blue: 0.42)),
                lineWidth: max(1, w * 0.09)
            )
            // 翼
            for side in [-1.0, 1.0] {
                context.fill(
                    Path(ellipseIn: CGRect(x: torsoRect.midX + side * torsoRect.width * 0.62 - torsoRect.width * 0.3,
                                           y: torsoRect.minY,
                                           width: torsoRect.width * 0.6,
                                           height: torsoRect.height * 0.85)),
                    with: .color(.white.opacity(0.75))
                )
            }

        case .astronaut:
            // ヘルメット
            context.stroke(
                Path(ellipseIn: headRect.insetBy(dx: -w * 0.14, dy: -w * 0.14)),
                with: .color(.white.opacity(0.9)),
                lineWidth: max(1, w * 0.12)
            )
            // 背中のタンク
            context.fill(
                Path(roundedRect: CGRect(x: torsoRect.midX - torsoRect.width * 0.22,
                                         y: torsoRect.minY + torsoRect.height * 0.1,
                                         width: torsoRect.width * 0.44,
                                         height: torsoRect.height * 0.6),
                     cornerRadius: torsoRect.width * 0.16),
                with: .color(Color(red: 0.68, green: 0.70, blue: 0.76))
            )
        }
    }

    // MARK: - 髪と帽子

    private static func drawHair(_ person: QueuePerson, in context: GraphicsContext, headRect: CGRect) {
        let width = headRect.width
        switch person.hairStyle {
        case .bald:
            break

        case .short:
            let cap = CGRect(
                x: headRect.minX,
                y: headRect.minY,
                width: width,
                height: headRect.height * 0.56
            )
            context.fill(
                Path(roundedRect: cap, cornerSize: CGSize(width: width * 0.5, height: width * 0.42)),
                with: .color(person.hair)
            )

        case .long:
            let hair = CGRect(
                x: headRect.minX - width * 0.08,
                y: headRect.minY,
                width: width * 1.16,
                height: headRect.height * 1.5
            )
            context.fill(
                Path(roundedRect: hair, cornerSize: CGSize(width: width * 0.55, height: width * 0.55)),
                with: .color(person.hair)
            )

        case .bun:
            let cap = CGRect(
                x: headRect.minX,
                y: headRect.minY,
                width: width,
                height: headRect.height * 0.6
            )
            context.fill(
                Path(roundedRect: cap, cornerSize: CGSize(width: width * 0.5, height: width * 0.4)),
                with: .color(person.hair)
            )
            let bun = CGRect(
                x: headRect.midX - width * 0.2,
                y: headRect.minY - width * 0.26,
                width: width * 0.4,
                height: width * 0.4
            )
            context.fill(Path(ellipseIn: bun), with: .color(person.hair))

        case .cap:
            let cap = CGRect(
                x: headRect.minX - width * 0.06,
                y: headRect.minY - width * 0.04,
                width: width * 1.12,
                height: headRect.height * 0.5
            )
            context.fill(
                Path(roundedRect: cap, cornerSize: CGSize(width: width * 0.4, height: width * 0.36)),
                with: .color(person.accent)
            )

        case .beanie:
            let hat = CGRect(
                x: headRect.minX - width * 0.05,
                y: headRect.minY - width * 0.1,
                width: width * 1.1,
                height: headRect.height * 0.62
            )
            context.fill(
                Path(roundedRect: hat, cornerSize: CGSize(width: width * 0.42, height: width * 0.42)),
                with: .color(person.accent)
            )
        }
    }

    // MARK: - 腕

    private static func drawArms(
        _ person: QueuePerson,
        in context: GraphicsContext,
        x: Double,
        shoulderY: Double,
        hipY: Double,
        torsoWidth: Double,
        armWidth: Double,
        height: Double
    ) {
        let raise = person.activity.armRaise
        let armLength = (hipY - shoulderY) * (1 - raise * 0.45) + height * 0.04

        for side in [-1.0, 1.0] {
            let armX = x + side * (torsoWidth * 0.5 + armWidth * 0.1) - armWidth / 2
            // 腕を上げるほど肩の位置から前に出て短く見える。
            let top = shoulderY + height * 0.01 - raise * height * 0.02
            let rect = CGRect(x: armX, y: top, width: armWidth, height: armLength)
            context.fill(
                Path(roundedRect: rect, cornerRadius: armWidth * 0.5),
                with: .color(person.top.opacity(0.86))
            )

            // 手
            let handSize = armWidth * 1.1
            let handRect = CGRect(
                x: armX + armWidth / 2 - handSize / 2,
                y: top + armLength - handSize * 0.35,
                width: handSize,
                height: handSize
            )
            context.fill(Path(ellipseIn: handRect), with: .color(person.skin))
        }
    }

    // MARK: - 持ち物

    /// 足元に置いてあるもの。
    private static func drawGroundItem(
        _ person: QueuePerson,
        in context: GraphicsContext,
        x: Double,
        bottomY: Double,
        height: Double,
        time: Double
    ) {
        switch person.activity {
        case .suitcase:
            let w = height * 0.14
            let h = height * 0.22
            let rect = CGRect(x: x + height * 0.2, y: bottomY - h, width: w, height: h)
            context.fill(
                Path(roundedRect: rect, cornerRadius: w * 0.18),
                with: .color(person.accent)
            )
            // 引き手
            let handle = CGRect(
                x: rect.midX - w * 0.06,
                y: rect.minY - h * 0.35,
                width: w * 0.12,
                height: h * 0.35
            )
            context.fill(Path(handle), with: .color(person.accent.opacity(0.7)))

        case .walkingDog:
            let bodyW = height * 0.16
            let bodyH = height * 0.09
            let bob = sin(time * 2.2 + person.swayPhase) * height * 0.006
            let body = CGRect(
                x: x - height * 0.34,
                y: bottomY - bodyH + bob,
                width: bodyW,
                height: bodyH
            )
            context.fill(
                Path(roundedRect: body, cornerRadius: bodyH * 0.45),
                with: .color(person.hair)
            )
            let head = CGRect(
                x: body.minX - bodyW * 0.28,
                y: body.minY - bodyH * 0.45,
                width: bodyW * 0.42,
                height: bodyH * 0.85
            )
            context.fill(Path(ellipseIn: head), with: .color(person.hair))

        case .shopping:
            let w = height * 0.1
            let h = height * 0.14
            let rect = CGRect(x: x + height * 0.17, y: bottomY - h, width: w, height: h)
            context.fill(Path(rect), with: .color(person.accent))

        default:
            break
        }
    }

    /// 手に持っているもの。
    private static func drawHeldItem(
        _ person: QueuePerson,
        in context: GraphicsContext,
        x: Double,
        shoulderY: Double,
        height: Double,
        torsoWidth: Double
    ) {
        switch person.activity {
        case .phone:
            let w = height * 0.045
            let rect = CGRect(x: x - w / 2, y: shoulderY + height * 0.06, width: w, height: w * 1.8)
            context.fill(
                Path(roundedRect: rect, cornerRadius: w * 0.2),
                with: .color(Color(red: 0.16, green: 0.17, blue: 0.2))
            )

        case .reading:
            let w = height * 0.11
            let rect = CGRect(x: x - w / 2, y: shoulderY + height * 0.05, width: w, height: w * 0.72)
            context.fill(Path(rect), with: .color(Color(red: 0.92, green: 0.90, blue: 0.85)))

        case .coffee:
            let w = height * 0.035
            let rect = CGRect(x: x + torsoWidth * 0.42, y: shoulderY + height * 0.09, width: w, height: w * 1.4)
            context.fill(
                Path(roundedRect: rect, cornerRadius: w * 0.15),
                with: .color(Color(red: 0.88, green: 0.84, blue: 0.78))
            )

        case .umbrella:
            let w = height * 0.012
            let rect = CGRect(x: x + torsoWidth * 0.55, y: shoulderY, width: w, height: height * 0.5)
            context.fill(Path(rect), with: .color(person.accent))

        case .music:
            // ヘッドホン
            let w = height * 0.2
            let rect = CGRect(x: x - w / 2, y: shoulderY - height * 0.16, width: w, height: height * 0.06)
            context.stroke(
                Path(roundedRect: rect, cornerRadius: w * 0.3),
                with: .color(person.accent),
                lineWidth: max(1, height * 0.014)
            )

        default:
            break
        }
    }
}
