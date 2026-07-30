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

        case .bicycle:
            drawSpeedLines(in: context, feet: feet, height: height, length: 0.9, time: time)
            drawTwoWheeler(
                in: context, feet: feet, height: height, time: time,
                wheelRadius: height * 0.13, bodyColor: Color(red: 0.24, green: 0.26, blue: 0.32),
                isMotor: false
            )

        case .motorbike:
            drawSpeedLines(in: context, feet: feet, height: height, length: 1.3, time: time)
            drawTwoWheeler(
                in: context, feet: feet, height: height, time: time,
                wheelRadius: height * 0.15, bodyColor: Color(red: 0.72, green: 0.16, blue: 0.16),
                isMotor: true
            )

        case .car:
            drawSpeedLines(in: context, feet: feet, height: height, length: 1.6, time: time)
            drawCar(in: context, feet: feet, height: height, time: time)

        case .train:
            drawSpeedLines(in: context, feet: feet, height: height, length: 2.2, time: time)
            drawTrain(in: context, feet: feet, height: height, time: time)
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
        time: Double
    ) {
        let bodyW = height * 0.95
        let bodyH = height * 0.3
        let wheelRadius = height * 0.1
        let bodyY = feet.y - wheelRadius * 1.2 - bodyH

        context.fill(
            Path(roundedRect: CGRect(x: feet.x - bodyW / 2, y: bodyY, width: bodyW, height: bodyH),
                 cornerRadius: bodyH * 0.34),
            with: .color(Color(red: 0.86, green: 0.24, blue: 0.22))
        )
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
