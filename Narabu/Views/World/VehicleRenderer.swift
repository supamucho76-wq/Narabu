import SwiftUI

/// ごぼう抜き中にプレイヤーが乗っているもの。
///
/// 人物より手前に描くので、乗っているように見える。
enum VehicleRenderer {
    /// - Parameters:
    ///   - feet: 乗り手の足元。
    ///   - height: 乗り手の背丈。乗り物の大きさはこれを基準にする。
    ///   - time: 車輪を回すのに使う。
    static func draw(
        _ kind: VehicleKind,
        in context: GraphicsContext,
        feet: CGPoint,
        height: Double,
        time: Double
    ) {
        switch kind {
        case .running:
            drawSpeedLines(in: context, feet: feet, height: height, length: 0.6, time: time)

        case .hopping:
            drawSpeedLines(in: context, feet: feet, height: height, length: 0.4, time: time)

        case .bicycle:
            drawSpeedLines(in: context, feet: feet, height: height, length: 0.9, time: time)
            drawTwoWheeler(
                in: context, feet: feet, height: height, time: time,
                wheelRadius: height * 0.13, bodyColor: Color(red: 0.24, green: 0.26, blue: 0.32),
                isMotor: false
            )

        case .scooter:
            drawSpeedLines(in: context, feet: feet, height: height, length: 0.8, time: time)
            drawTwoWheeler(
                in: context, feet: feet, height: height, time: time,
                wheelRadius: height * 0.08, bodyColor: Color(red: 0.32, green: 0.62, blue: 0.72),
                isMotor: false
            )

        case .cart:
            drawSpeedLines(in: context, feet: feet, height: height, length: 0.8, time: time)
            drawCart(in: context, feet: feet, height: height, time: time)

        case .motorbike:
            drawSpeedLines(in: context, feet: feet, height: height, length: 1.3, time: time)
            drawTwoWheeler(
                in: context, feet: feet, height: height, time: time,
                wheelRadius: height * 0.15, bodyColor: Color(red: 0.72, green: 0.16, blue: 0.16),
                isMotor: true
            )

        case .gang:
            drawSpeedLines(in: context, feet: feet, height: height, length: 1.8, time: time)
            // 何台も連なって走ってくる。
            for index in 0..<3 {
                let offset = Double(index) * height * 0.55
                drawTwoWheeler(
                    in: context,
                    feet: CGPoint(x: feet.x + offset, y: feet.y),
                    height: height * (1 - Double(index) * 0.08),
                    time: time + Double(index),
                    wheelRadius: height * 0.14,
                    bodyColor: Color(red: 0.86, green: 0.24, blue: 0.14),
                    isMotor: true
                )
            }

        case .palanquin:
            drawSpeedLines(in: context, feet: feet, height: height, length: 0.9, time: time)
            drawPalanquin(in: context, feet: feet, height: height, time: time)

        case .animal:
            drawSpeedLines(in: context, feet: feet, height: height, length: 1.4, time: time)
            drawBird(in: context, feet: feet, height: height, time: time)

        case .dinosaur:
            drawSpeedLines(in: context, feet: feet, height: height, length: 1.8, time: time)
            drawDinosaur(in: context, feet: feet, height: height, time: time)

        case .car:
            drawSpeedLines(in: context, feet: feet, height: height, length: 1.6, time: time)
            drawCar(in: context, feet: feet, height: height, time: time,
                    body: Color(red: 0.86, green: 0.24, blue: 0.22))

        case .fireTruck:
            drawSpeedLines(in: context, feet: feet, height: height, length: 1.7, time: time)
            drawCar(in: context, feet: feet, height: height, time: time,
                    body: Color(red: 0.78, green: 0.14, blue: 0.12), hasSiren: true)

        case .helicopter:
            drawSpeedLines(in: context, feet: feet, height: height, length: 2.0, time: time)
            drawHelicopter(in: context, feet: feet, height: height, time: time)

        case .train:
            drawSpeedLines(in: context, feet: feet, height: height, length: 2.2, time: time)
            drawTrain(in: context, feet: feet, height: height, time: time)

        case .ufo:
            drawUFO(in: context, feet: feet, height: height, time: time)

        case .rocket:
            drawSpeedLines(in: context, feet: feet, height: height, length: 2.6, time: time)
            drawRocket(in: context, feet: feet, height: height, time: time)

        case .divineHand:
            drawDivineHand(in: context, feet: feet, height: height, time: time)
        }
    }

    // MARK: - 速度線

    private static func drawSpeedLines(
        in context: GraphicsContext,
        feet: CGPoint,
        height: Double,
        length: Double,
        time: Double
    ) {
        for index in 0..<9 {
            let seed = index
            let offset = (time * 900 + Double(index) * 70)
                .truncatingRemainder(dividingBy: 320)
            let y = feet.y - height * (0.15 + QueueEngine.unitRandom(seed, salt: 0x9A1C) * 0.9)
            let lineLength = height * length * (0.3 + QueueEngine.unitRandom(seed, salt: 0xAB2D) * 0.7)
            let x = feet.x + height * 0.4 + offset

            context.fill(
                Path(CGRect(x: x, y: y, width: lineLength, height: max(1.2, height * 0.012))),
                with: .color(.white.opacity(0.5))
            )
        }
    }

    // MARK: - 乗り物

    private static func drawTwoWheeler(
        in context: GraphicsContext,
        feet: CGPoint,
        height: Double,
        time: Double,
        wheelRadius: Double,
        bodyColor: Color,
        isMotor: Bool
    ) {
        let spacing = height * 0.42
        let axleY = feet.y - wheelRadius

        for side in [-1.0, 1.0] {
            let center = CGPoint(x: feet.x + side * spacing / 2, y: axleY)
            context.fill(
                Path(ellipseIn: CGRect(
                    x: center.x - wheelRadius, y: center.y - wheelRadius,
                    width: wheelRadius * 2, height: wheelRadius * 2
                )),
                with: .color(Color(red: 0.14, green: 0.14, blue: 0.16))
            )
            // 回転しているのがわかるスポーク
            let angle = time * 14
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(
                        x: center.x + cos(angle) * wheelRadius * 0.7,
                        y: center.y + sin(angle) * wheelRadius * 0.7
                    ))
                    path.addLine(to: CGPoint(
                        x: center.x - cos(angle) * wheelRadius * 0.7,
                        y: center.y - sin(angle) * wheelRadius * 0.7
                    ))
                },
                with: .color(.white.opacity(0.55)),
                lineWidth: max(1, wheelRadius * 0.14)
            )
        }

        let bodyHeight = isMotor ? height * 0.14 : height * 0.08
        context.fill(
            Path(roundedRect: CGRect(
                x: feet.x - spacing / 2, y: axleY - bodyHeight,
                width: spacing, height: bodyHeight
            ), cornerRadius: bodyHeight * 0.45),
            with: .color(bodyColor)
        )
    }

    private static func drawCar(
        in context: GraphicsContext,
        feet: CGPoint,
        height: Double,
        time: Double,
        body: Color = Color(red: 0.86, green: 0.24, blue: 0.22),
        hasSiren: Bool = false
    ) {
        let bodyW = height * 0.95
        let bodyH = height * 0.3
        let wheelRadius = height * 0.1
        let bodyY = feet.y - wheelRadius * 1.2 - bodyH

        context.fill(
            Path(roundedRect: CGRect(x: feet.x - bodyW / 2, y: bodyY, width: bodyW, height: bodyH),
                 cornerRadius: bodyH * 0.34),
            with: .color(body)
        )

        if hasSiren {
            // 赤色灯。点滅させる。
            let blink = sin(time * 9) > 0
            let r = height * 0.07
            context.fill(
                Path(ellipseIn: CGRect(x: feet.x - r / 2, y: bodyY - bodyH * 0.9,
                                       width: r, height: r * 0.8)),
                with: .color(blink
                    ? Color(red: 1.0, green: 0.3, blue: 0.24)
                    : Color(red: 0.6, green: 0.2, blue: 0.18))
            )
        }
        // 屋根
        context.fill(
            Path(roundedRect: CGRect(x: feet.x - bodyW * 0.28, y: bodyY - bodyH * 0.55,
                                     width: bodyW * 0.56, height: bodyH * 0.62),
                 cornerRadius: bodyH * 0.24),
            with: .color(Color(red: 0.72, green: 0.18, blue: 0.16))
        )
        // 窓
        context.fill(
            Path(roundedRect: CGRect(x: feet.x - bodyW * 0.22, y: bodyY - bodyH * 0.45,
                                     width: bodyW * 0.44, height: bodyH * 0.42),
                 cornerRadius: bodyH * 0.14),
            with: .color(Color(red: 0.72, green: 0.86, blue: 0.94).opacity(0.85))
        )

        for side in [-1.0, 1.0] {
            let center = CGPoint(x: feet.x + side * bodyW * 0.3, y: feet.y - wheelRadius)
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - wheelRadius, y: center.y - wheelRadius,
                                       width: wheelRadius * 2, height: wheelRadius * 2)),
                with: .color(Color(red: 0.12, green: 0.12, blue: 0.14))
            )
            let angle = time * 18
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: center.x + cos(angle) * wheelRadius * 0.6,
                                          y: center.y + sin(angle) * wheelRadius * 0.6))
                    path.addLine(to: CGPoint(x: center.x - cos(angle) * wheelRadius * 0.6,
                                             y: center.y - sin(angle) * wheelRadius * 0.6))
                },
                with: .color(.white.opacity(0.5)),
                lineWidth: max(1, wheelRadius * 0.16)
            )
        }
    }

    /// 台車。荷物ごと押していく。
    private static func drawCart(
        in context: GraphicsContext,
        feet: CGPoint,
        height: Double,
        time: Double
    ) {
        let w = height * 0.5
        let deckY = feet.y - height * 0.1
        // 荷物が揺れて、雑に押しているのが伝わる。
        let rattle = sin(time * 13) * height * 0.012
        context.fill(
            Path(CGRect(x: feet.x - w / 2, y: deckY, width: w, height: height * 0.05)),
            with: .color(Color(red: 0.42, green: 0.44, blue: 0.48))
        )
        // 積み荷
        context.fill(
            Path(CGRect(x: feet.x - w * 0.3 + rattle, y: deckY - height * 0.24,
                        width: w * 0.6, height: height * 0.24)),
            with: .color(Color(red: 0.72, green: 0.56, blue: 0.34))
        )
        for side in [-1.0, 1.0] {
            let r = height * 0.045
            context.fill(
                Path(ellipseIn: CGRect(x: feet.x + side * w * 0.35 - r, y: feet.y - r * 2,
                                       width: r * 2, height: r * 2)),
                with: .color(Color(red: 0.16, green: 0.16, blue: 0.18))
            )
        }
    }

    /// 神輿。担がれて進む。
    private static func drawPalanquin(
        in context: GraphicsContext,
        feet: CGPoint,
        height: Double,
        time: Double
    ) {
        let bounce = sin(time * 5) * height * 0.03
        let w = height * 0.6
        let bodyY = feet.y - height * 0.62 + bounce

        // 担ぎ棒
        context.fill(
            Path(CGRect(x: feet.x - w * 0.85, y: bodyY + height * 0.2,
                        width: w * 1.7, height: max(2, height * 0.03))),
            with: .color(Color(red: 0.52, green: 0.38, blue: 0.22))
        )
        // 本体
        context.fill(
            Path(CGRect(x: feet.x - w / 2, y: bodyY, width: w, height: height * 0.24)),
            with: .color(Color(red: 0.72, green: 0.16, blue: 0.14))
        )
        // 金の屋根
        var roof = Path()
        roof.move(to: CGPoint(x: feet.x - w * 0.62, y: bodyY))
        roof.addLine(to: CGPoint(x: feet.x, y: bodyY - height * 0.18))
        roof.addLine(to: CGPoint(x: feet.x + w * 0.62, y: bodyY))
        roof.closeSubpath()
        context.fill(roof, with: .color(Color(red: 0.90, green: 0.74, blue: 0.26)))
    }

    /// ダチョウ。走るたびに脚が入れ替わる。
    private static func drawBird(
        in context: GraphicsContext,
        feet: CGPoint,
        height: Double,
        time: Double
    ) {
        let bodyW = height * 0.5
        let bodyH = height * 0.28
        let bodyY = feet.y - height * 0.5

        context.fill(
            Path(ellipseIn: CGRect(x: feet.x - bodyW / 2, y: bodyY, width: bodyW, height: bodyH)),
            with: .color(Color(red: 0.42, green: 0.34, blue: 0.28))
        )
        // 首と頭
        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: feet.x + bodyW * 0.3, y: bodyY + bodyH * 0.3))
                path.addQuadCurve(
                    to: CGPoint(x: feet.x + bodyW * 0.75, y: bodyY - height * 0.2),
                    control: CGPoint(x: feet.x + bodyW * 0.8, y: bodyY)
                )
            },
            with: .color(Color(red: 0.86, green: 0.74, blue: 0.62)),
            lineWidth: max(2, height * 0.035)
        )
        // 脚
        for side in [-1.0, 1.0] {
            let swing = sin(time * 11 + (side > 0 ? 0 : Double.pi)) * height * 0.12
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: feet.x, y: bodyY + bodyH))
                    path.addLine(to: CGPoint(x: feet.x + swing, y: feet.y))
                },
                with: .color(Color(red: 0.86, green: 0.72, blue: 0.36)),
                lineWidth: max(2, height * 0.028)
            )
        }
    }

    /// ティラノサウルス。乗り手を背中に乗せて走る。
    private static func drawDinosaur(
        in context: GraphicsContext,
        feet: CGPoint,
        height: Double,
        time: Double
    ) {
        let bodyW = height * 0.9
        let bodyH = height * 0.34
        let bodyY = feet.y - height * 0.62
        let skin = Color(red: 0.34, green: 0.54, blue: 0.32)

        context.fill(
            Path(ellipseIn: CGRect(x: feet.x - bodyW / 2, y: bodyY, width: bodyW, height: bodyH)),
            with: .color(skin)
        )
        // 頭
        context.fill(
            Path(roundedRect: CGRect(x: feet.x + bodyW * 0.32, y: bodyY - height * 0.12,
                                     width: bodyW * 0.36, height: bodyH * 0.7),
                 cornerRadius: bodyH * 0.2),
            with: .color(skin)
        )
        // しっぽ
        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: feet.x - bodyW * 0.42, y: bodyY + bodyH * 0.4))
                path.addQuadCurve(
                    to: CGPoint(x: feet.x - bodyW, y: bodyY - height * 0.05),
                    control: CGPoint(x: feet.x - bodyW * 0.75, y: bodyY + bodyH * 0.6)
                )
            },
            with: .color(skin),
            lineWidth: max(3, height * 0.05)
        )
        // 脚
        for side in [-1.0, 1.0] {
            let swing = sin(time * 8 + (side > 0 ? 0 : Double.pi)) * height * 0.1
            context.fill(
                Path(roundedRect: CGRect(x: feet.x + swing - height * 0.04,
                                         y: bodyY + bodyH * 0.7,
                                         width: height * 0.08,
                                         height: height * 0.36),
                     cornerRadius: height * 0.03),
                with: .color(skin)
            )
        }
    }

    /// ヘリコプター。羽根が回って浮いている。
    private static func drawHelicopter(
        in context: GraphicsContext,
        feet: CGPoint,
        height: Double,
        time: Double
    ) {
        let float = sin(time * 2.4) * height * 0.04
        let bodyW = height * 0.7
        let bodyH = height * 0.3
        let bodyY = feet.y - height * 0.85 + float

        context.fill(
            Path(ellipseIn: CGRect(x: feet.x - bodyW / 2, y: bodyY, width: bodyW, height: bodyH)),
            with: .color(Color(red: 0.24, green: 0.42, blue: 0.66))
        )
        // 尾
        context.fill(
            Path(CGRect(x: feet.x - bodyW, y: bodyY + bodyH * 0.35,
                        width: bodyW * 0.55, height: max(2, height * 0.035))),
            with: .color(Color(red: 0.24, green: 0.42, blue: 0.66))
        )
        // 回るローター
        let spin = abs(cos(time * 16))
        context.fill(
            Path(ellipseIn: CGRect(x: feet.x - bodyW * (0.5 + spin * 0.5),
                                   y: bodyY - height * 0.1,
                                   width: bodyW * (1 + spin), height: max(2, height * 0.02))),
            with: .color(.white.opacity(0.7))
        )
        // 支柱
        context.fill(
            Path(CGRect(x: feet.x - max(1, height * 0.012), y: bodyY - height * 0.1,
                        width: max(2, height * 0.024), height: height * 0.1)),
            with: .color(Color(red: 0.3, green: 0.3, blue: 0.34))
        )
    }

    /// UFO。光を落として吸い上げる。
    private static func drawUFO(
        in context: GraphicsContext,
        feet: CGPoint,
        height: Double,
        time: Double
    ) {
        let float = sin(time * 1.8) * height * 0.05
        let w = height * 0.9
        let bodyY = feet.y - height * 1.15 + float

        // 吸い上げる光
        var beam = Path()
        beam.move(to: CGPoint(x: feet.x - w * 0.16, y: bodyY + height * 0.08))
        beam.addLine(to: CGPoint(x: feet.x + w * 0.16, y: bodyY + height * 0.08))
        beam.addLine(to: CGPoint(x: feet.x + w * 0.42, y: feet.y))
        beam.addLine(to: CGPoint(x: feet.x - w * 0.42, y: feet.y))
        beam.closeSubpath()
        context.fill(beam, with: .color(Color(red: 0.66, green: 0.94, blue: 0.62).opacity(0.35)))

        // 円盤
        context.fill(
            Path(ellipseIn: CGRect(x: feet.x - w / 2, y: bodyY, width: w, height: height * 0.16)),
            with: .color(Color(red: 0.52, green: 0.56, blue: 0.66))
        )
        // ドーム
        context.fill(
            Path(ellipseIn: CGRect(x: feet.x - w * 0.22, y: bodyY - height * 0.12,
                                   width: w * 0.44, height: height * 0.2)),
            with: .color(Color(red: 0.72, green: 0.94, blue: 0.72).opacity(0.9))
        )
        // 回る光
        for index in 0..<5 {
            let angle = time * 3 + Double(index) * 1.25
            let x = feet.x + cos(angle) * w * 0.38
            let r = height * 0.028
            context.fill(
                Path(ellipseIn: CGRect(x: x - r / 2, y: bodyY + height * 0.09, width: r, height: r)),
                with: .color(Color(red: 1.0, green: 0.92, blue: 0.5))
            )
        }
    }

    /// ロケット。噴射しながら飛んでいく。
    private static func drawRocket(
        in context: GraphicsContext,
        feet: CGPoint,
        height: Double,
        time: Double
    ) {
        let w = height * 0.22
        let bodyH = height * 0.62
        let bodyY = feet.y - height * 0.75

        context.fill(
            Path(roundedRect: CGRect(x: feet.x - w / 2, y: bodyY, width: w, height: bodyH),
                 cornerRadius: w * 0.4),
            with: .color(Color(red: 0.92, green: 0.92, blue: 0.94))
        )
        // 先端
        var nose = Path()
        nose.move(to: CGPoint(x: feet.x - w / 2, y: bodyY))
        nose.addLine(to: CGPoint(x: feet.x, y: bodyY - height * 0.16))
        nose.addLine(to: CGPoint(x: feet.x + w / 2, y: bodyY))
        nose.closeSubpath()
        context.fill(nose, with: .color(Color(red: 0.86, green: 0.24, blue: 0.20)))

        // 噴射
        let flare = 0.7 + abs(sin(time * 22)) * 0.6
        context.fill(
            Path(ellipseIn: CGRect(x: feet.x - w * 0.34, y: bodyY + bodyH,
                                   width: w * 0.68, height: height * 0.24 * flare)),
            with: .color(Color(red: 1.0, green: 0.68, blue: 0.24).opacity(0.9))
        )
    }

    /// 神様の手。上からつまんで運ばれる。
    private static func drawDivineHand(
        in context: GraphicsContext,
        feet: CGPoint,
        height: Double,
        time: Double
    ) {
        let float = sin(time * 1.2) * height * 0.03
        let w = height * 0.6
        let handY = feet.y - height * 1.5 + float

        // 差し込む光。画面の上端から手のひらまで。
        // 遠くの小さい人だと手が画面外に出るので、高さは必ず正の値にしておく。
        let beamBottom = max(height * 0.4, handY + height * 0.4)
        context.fill(
            Path(CGRect(x: feet.x - w * 0.5, y: 0, width: w, height: beamBottom)),
            with: .linearGradient(
                Gradient(colors: [Color(red: 1.0, green: 0.96, blue: 0.72).opacity(0.5), .clear]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: beamBottom)
            )
        )

        // 手のひら
        context.fill(
            Path(roundedRect: CGRect(x: feet.x - w / 2, y: handY, width: w, height: height * 0.3),
                 cornerRadius: w * 0.3),
            with: .color(Color(red: 0.98, green: 0.90, blue: 0.78))
        )
        // 指
        for index in 0..<4 {
            let fingerW = w * 0.16
            let x = feet.x - w * 0.36 + Double(index) * w * 0.24
            context.fill(
                Path(roundedRect: CGRect(x: x, y: handY + height * 0.24,
                                         width: fingerW, height: height * 0.22),
                     cornerRadius: fingerW * 0.5),
                with: .color(Color(red: 0.98, green: 0.90, blue: 0.78))
            )
        }
    }

    /// 電車だけは特別扱い。線路ごと現れる。
    private static func drawTrain(
        in context: GraphicsContext,
        feet: CGPoint,
        height: Double,
        time: Double
    ) {
        // 線路
        let railY = feet.y + height * 0.02
        context.fill(
            Path(CGRect(x: 0, y: railY, width: 4_000, height: max(2, height * 0.02))),
            with: .color(Color(red: 0.42, green: 0.42, blue: 0.46))
        )
        let sleeperOffset = (time * 700).truncatingRemainder(dividingBy: height * 0.3)
        for index in -2..<24 {
            let x = feet.x - height * 2 + Double(index) * height * 0.3 + sleeperOffset
            context.fill(
                Path(CGRect(x: x, y: railY - height * 0.02, width: height * 0.07, height: height * 0.06)),
                with: .color(Color(red: 0.34, green: 0.28, blue: 0.24))
            )
        }

        let bodyW = height * 1.5
        let bodyH = height * 0.62
        let bodyY = feet.y - height * 0.12 - bodyH

        context.fill(
            Path(roundedRect: CGRect(x: feet.x - bodyW * 0.62, y: bodyY, width: bodyW, height: bodyH),
                 cornerRadius: bodyH * 0.18),
            with: .color(Color(red: 0.20, green: 0.36, blue: 0.62))
        )
        // 帯
        context.fill(
            Path(CGRect(x: feet.x - bodyW * 0.62, y: bodyY + bodyH * 0.52, width: bodyW, height: bodyH * 0.12)),
            with: .color(Color(red: 0.94, green: 0.82, blue: 0.28))
        )
        // 窓
        for index in 0..<4 {
            let w = bodyW * 0.16
            let x = feet.x - bodyW * 0.52 + Double(index) * bodyW * 0.22
            context.fill(
                Path(roundedRect: CGRect(x: x, y: bodyY + bodyH * 0.16, width: w, height: bodyH * 0.3),
                     cornerRadius: bodyH * 0.06),
                with: .color(Color(red: 0.76, green: 0.88, blue: 0.96).opacity(0.9))
            )
        }
    }
}
