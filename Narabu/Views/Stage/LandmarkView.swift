import SwiftUI

/// 行列の先にあった場所を絵で見せる。
///
/// 数字だけで「クリア」と言われても、どこに着いたのか分からない。
/// たどり着いた場所が目に見えると、次はどこだろうという気持ちが残る。
struct LandmarkView: View {
    let stage: Stage
    /// 影だけ見せる。次のステージの予告に使う。
    var isSilhouette = false

    var body: some View {
        Canvas { context, size in
            draw(in: context, size: size)
        }
        .frame(height: 132)
    }

    private func draw(in context: GraphicsContext, size: CGSize) {
        let ground = size.height * 0.88
        let centerX = size.width / 2

        var canvas = context
        if isSilhouette {
            canvas.opacity = 0.35
        }

        switch stage.id {
        case 1: drawConvenienceStore(in: canvas, centerX: centerX, ground: ground, size: size)
        case 2: drawRamenShop(in: canvas, centerX: centerX, ground: ground, size: size)
        case 3: drawCafe(in: canvas, centerX: centerX, ground: ground, size: size)
        case 4: drawThemePark(in: canvas, centerX: centerX, ground: ground, size: size)
        case 5: drawLiveVenue(in: canvas, centerX: centerX, ground: ground, size: size)
        case 6: drawConventionHall(in: canvas, centerX: centerX, ground: ground, size: size)
        default: drawGrandRamenShop(in: canvas, centerX: centerX, ground: ground, size: size)
        }
    }

    /// 影で見せるときは中身を塗りつぶす。
    private func tint(_ color: Color) -> Color {
        isSilhouette ? Color(red: 0.16, green: 0.14, blue: 0.16) : color
    }

    // MARK: - 各ステージ

    private func drawConvenienceStore(in context: GraphicsContext, centerX: Double, ground: Double, size: CGSize) {
        let w = size.width * 0.52
        let h = ground * 0.52
        let body = CGRect(x: centerX - w / 2, y: ground - h, width: w, height: h)

        context.fill(Path(body), with: .color(tint(Color(red: 0.94, green: 0.94, blue: 0.92))))
        // 三色の看板
        let signHeight = h * 0.2
        let stripe = w / 3
        for (index, color) in [
            Color(red: 0.20, green: 0.52, blue: 0.34),
            Color(red: 0.94, green: 0.62, blue: 0.20),
            Color(red: 0.82, green: 0.24, blue: 0.24)
        ].enumerated() {
            context.fill(
                Path(CGRect(x: body.minX + Double(index) * stripe, y: body.minY,
                            width: stripe, height: signHeight)),
                with: .color(tint(color))
            )
        }
        // 明るい窓
        context.fill(
            Path(CGRect(x: body.minX + w * 0.08, y: body.minY + signHeight + h * 0.1,
                        width: w * 0.84, height: h * 0.5)),
            with: .color(tint(Color(red: 0.98, green: 0.96, blue: 0.78)))
        )
    }

    private func drawRamenShop(in context: GraphicsContext, centerX: Double, ground: Double, size: CGSize) {
        let w = size.width * 0.5
        let h = ground * 0.5
        let body = CGRect(x: centerX - w / 2, y: ground - h, width: w, height: h)

        context.fill(Path(body), with: .color(tint(Color(red: 0.36, green: 0.24, blue: 0.18))))

        // 赤い暖簾
        let norenHeight = h * 0.3
        for index in 0..<5 {
            let stripeW = w / 5.4
            let x = body.minX + w * 0.03 + Double(index) * (stripeW + w * 0.008)
            context.fill(
                Path(CGRect(x: x, y: body.minY, width: stripeW, height: norenHeight)),
                with: .color(tint(Color(red: 0.76, green: 0.16, blue: 0.14)))
            )
        }

        // 提灯
        for side in [-1.0, 1.0] {
            let r = w * 0.11
            context.fill(
                Path(ellipseIn: CGRect(x: centerX + side * w * 0.36 - r / 2,
                                       y: body.minY - r * 1.4, width: r, height: r * 1.3)),
                with: .color(tint(Color(red: 0.88, green: 0.24, blue: 0.18)))
            )
        }

        drawSteam(in: context, centerX: centerX, top: body.minY - h * 0.55, size: size)
    }

    private func drawCafe(in context: GraphicsContext, centerX: Double, ground: Double, size: CGSize) {
        let w = size.width * 0.48
        let h = ground * 0.46
        let body = CGRect(x: centerX - w / 2, y: ground - h, width: w, height: h)

        context.fill(Path(body), with: .color(tint(Color(red: 0.90, green: 0.86, blue: 0.78))))

        // 日よけ
        var awning = Path()
        awning.move(to: CGPoint(x: body.minX - w * 0.08, y: body.minY + h * 0.22))
        awning.addLine(to: CGPoint(x: body.maxX + w * 0.08, y: body.minY + h * 0.22))
        awning.addLine(to: CGPoint(x: body.maxX, y: body.minY))
        awning.addLine(to: CGPoint(x: body.minX, y: body.minY))
        awning.closeSubpath()
        context.fill(awning, with: .color(tint(Color(red: 0.34, green: 0.52, blue: 0.40))))

        // カップ
        let cupW = w * 0.2
        let cup = CGRect(x: centerX - cupW / 2, y: body.midY, width: cupW, height: cupW * 0.9)
        context.fill(
            Path(roundedRect: cup, cornerRadius: cupW * 0.12),
            with: .color(tint(.white))
        )
        drawSteam(in: context, centerX: centerX, top: cup.minY - h * 0.3, size: size)
    }

    private func drawThemePark(in context: GraphicsContext, centerX: Double, ground: Double, size: CGSize) {
        // 城
        let w = size.width * 0.34
        let h = ground * 0.62
        let body = CGRect(x: centerX - w / 2, y: ground - h, width: w, height: h)
        context.fill(Path(body), with: .color(tint(Color(red: 0.92, green: 0.90, blue: 0.94))))

        // 塔
        for side in [-1.0, 1.0] {
            let towerW = w * 0.3
            let towerH = h * 1.15
            let tower = CGRect(x: centerX + side * w * 0.55 - towerW / 2,
                               y: ground - towerH, width: towerW, height: towerH)
            context.fill(Path(tower), with: .color(tint(Color(red: 0.88, green: 0.86, blue: 0.92))))
            drawSpire(in: context, rect: tower, color: tint(Color(red: 0.32, green: 0.52, blue: 0.78)))
        }
        drawSpire(in: context, rect: body, color: tint(Color(red: 0.82, green: 0.30, blue: 0.36)))
    }

    private func drawSpire(in context: GraphicsContext, rect: CGRect, color: Color) {
        var spire = Path()
        spire.move(to: CGPoint(x: rect.minX, y: rect.minY))
        spire.addLine(to: CGPoint(x: rect.midX, y: rect.minY - rect.width * 0.8))
        spire.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        spire.closeSubpath()
        context.fill(spire, with: .color(color))
    }

    private func drawLiveVenue(in context: GraphicsContext, centerX: Double, ground: Double, size: CGSize) {
        let w = size.width * 0.62
        let h = ground * 0.44
        let body = CGRect(x: centerX - w / 2, y: ground - h, width: w, height: h)
        context.fill(Path(body), with: .color(tint(Color(red: 0.22, green: 0.20, blue: 0.30))))

        // ステージの光
        for index in 0..<3 {
            let x = body.minX + w * (0.25 + Double(index) * 0.25)
            var beam = Path()
            beam.move(to: CGPoint(x: x - 4, y: body.minY))
            beam.addLine(to: CGPoint(x: x + 4, y: body.minY))
            beam.addLine(to: CGPoint(x: x + 34, y: 0))
            beam.addLine(to: CGPoint(x: x - 34, y: 0))
            beam.closeSubpath()
            context.fill(beam, with: .color(tint(Color(red: 0.86, green: 0.62, blue: 1.0)).opacity(0.5)))
        }

        context.fill(
            Path(CGRect(x: body.minX + w * 0.1, y: body.midY, width: w * 0.8, height: h * 0.3)),
            with: .color(tint(Color(red: 0.96, green: 0.82, blue: 0.34)))
        )
    }

    private func drawConventionHall(in context: GraphicsContext, centerX: Double, ground: Double, size: CGSize) {
        let w = size.width * 0.72
        let h = ground * 0.42
        let body = CGRect(x: centerX - w / 2, y: ground - h, width: w, height: h)
        context.fill(Path(body), with: .color(tint(Color(red: 0.68, green: 0.70, blue: 0.74))))

        // 逆三角の屋根
        var roof = Path()
        roof.move(to: CGPoint(x: body.minX, y: body.minY))
        roof.addLine(to: CGPoint(x: body.maxX, y: body.minY))
        roof.addLine(to: CGPoint(x: centerX, y: body.minY - h * 0.5))
        roof.closeSubpath()
        context.fill(roof, with: .color(tint(Color(red: 0.52, green: 0.56, blue: 0.62))))

        // 横断幕
        context.fill(
            Path(CGRect(x: body.minX + w * 0.12, y: body.minY + h * 0.28,
                        width: w * 0.76, height: h * 0.24)),
            with: .color(tint(Color(red: 0.86, green: 0.28, blue: 0.30)))
        )
    }

    private func drawGrandRamenShop(in context: GraphicsContext, centerX: Double, ground: Double, size: CGSize) {
        let w = size.width * 0.6
        let h = ground * 0.54
        let body = CGRect(x: centerX - w / 2, y: ground - h, width: w, height: h)
        context.fill(Path(body), with: .color(tint(Color(red: 0.30, green: 0.18, blue: 0.14))))

        // 反った屋根
        var roof = Path()
        roof.move(to: CGPoint(x: body.minX - w * 0.14, y: body.minY))
        roof.addQuadCurve(to: CGPoint(x: body.maxX + w * 0.14, y: body.minY),
                          control: CGPoint(x: centerX, y: body.minY - h * 0.55))
        roof.closeSubpath()
        context.fill(roof, with: .color(tint(Color(red: 0.62, green: 0.16, blue: 0.14))))

        // 暖簾
        for index in 0..<6 {
            let stripeW = w / 6.6
            let x = body.minX + w * 0.03 + Double(index) * (stripeW + w * 0.006)
            context.fill(
                Path(CGRect(x: x, y: body.minY + h * 0.08, width: stripeW, height: h * 0.34)),
                with: .color(tint(Color(red: 0.86, green: 0.20, blue: 0.16)))
            )
        }

        // 大きな提灯
        for side in [-1.0, 1.0] {
            let r = w * 0.14
            context.fill(
                Path(ellipseIn: CGRect(x: centerX + side * w * 0.4 - r / 2,
                                       y: body.minY - r * 1.2, width: r, height: r * 1.35)),
                with: .color(tint(Color(red: 0.92, green: 0.26, blue: 0.18)))
            )
        }

        drawSteam(in: context, centerX: centerX, top: body.minY - h * 0.7, size: size)
    }

    /// 湯気。ラーメンらしさはこれで出る。
    private func drawSteam(in context: GraphicsContext, centerX: Double, top: Double, size: CGSize) {
        guard !isSilhouette else { return }

        for index in 0..<3 {
            let offset = Double(index - 1) * size.width * 0.07
            var steam = Path()
            steam.move(to: CGPoint(x: centerX + offset, y: top + 26))
            steam.addQuadCurve(to: CGPoint(x: centerX + offset, y: top),
                               control: CGPoint(x: centerX + offset + 14, y: top + 13))
            context.stroke(steam, with: .color(.white.opacity(0.55)), lineWidth: 3)
        }
    }
}
