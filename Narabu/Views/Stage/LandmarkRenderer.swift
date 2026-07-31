import SwiftUI

/// 行列の先にある場所の絵。
///
/// クリア画面と、並んでいる最中の地平線の両方で同じ絵を使う。
/// 遠くに小さく見えていたものが、着いたら目の前に現れる、という繋がりを作るため。
enum LandmarkRenderer {
    /// - Parameters:
    ///   - rect: 絵を収める枠。地面は枠の下辺。
    ///   - silhouette: 影だけ描く。次の行き先の予告に使う。
    static func draw(
        stage: Stage,
        in context: GraphicsContext,
        rect: CGRect,
        silhouette: Bool = false,
        showsSteam: Bool = true
    ) {
        var canvas = context
        if silhouette { canvas.opacity = 0.35 }

        let shape = Shape(rect: rect, silhouette: silhouette, showsSteam: showsSteam)

        switch stage.id {
        case 1: shape.convenienceStore(in: canvas)
        case 2: shape.ramenShop(in: canvas)
        case 3: shape.cafe(in: canvas)
        case 4: shape.themePark(in: canvas)
        case 5: shape.liveVenue(in: canvas)
        case 6: shape.conventionHall(in: canvas)
        default: shape.grandRamenShop(in: canvas)
        }
    }

    /// 枠の中に部品を並べるための入れもの。
    private struct Shape {
        let rect: CGRect
        let silhouette: Bool
        let showsSteam: Bool

        var centerX: Double { rect.midX }
        var ground: Double { rect.maxY }
        var unit: Double { rect.width }

        /// 影で見せるときは中身を塗りつぶす。
        func tint(_ color: Color) -> Color {
            silhouette ? Color(red: 0.16, green: 0.14, blue: 0.16) : color
        }

        // MARK: - コンビニ

        func convenienceStore(in context: GraphicsContext) {
            let w = unit * 0.52
            let h = rect.height * 0.52
            let body = CGRect(x: centerX - w / 2, y: ground - h, width: w, height: h)

            context.fill(Path(body), with: .color(tint(Color(red: 0.94, green: 0.94, blue: 0.92))))

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

            context.fill(
                Path(CGRect(x: body.minX + w * 0.08, y: body.minY + signHeight + h * 0.1,
                            width: w * 0.84, height: h * 0.5)),
                with: .color(tint(Color(red: 0.98, green: 0.96, blue: 0.78)))
            )
        }

        // MARK: - ラーメン屋

        func ramenShop(in context: GraphicsContext) {
            let w = unit * 0.5
            let h = rect.height * 0.5
            let body = CGRect(x: centerX - w / 2, y: ground - h, width: w, height: h)

            context.fill(Path(body), with: .color(tint(Color(red: 0.36, green: 0.24, blue: 0.18))))
            noren(in: context, over: body, stripes: 5, height: h * 0.3)
            lanterns(in: context, over: body, radius: w * 0.11, spread: 0.36)
            steam(in: context, top: body.minY - h * 0.55)
        }

        func grandRamenShop(in context: GraphicsContext) {
            let w = unit * 0.6
            let h = rect.height * 0.54
            let body = CGRect(x: centerX - w / 2, y: ground - h, width: w, height: h)

            context.fill(Path(body), with: .color(tint(Color(red: 0.30, green: 0.18, blue: 0.14))))

            // 反った屋根
            var roof = Path()
            roof.move(to: CGPoint(x: body.minX - w * 0.14, y: body.minY))
            roof.addQuadCurve(to: CGPoint(x: body.maxX + w * 0.14, y: body.minY),
                              control: CGPoint(x: centerX, y: body.minY - h * 0.55))
            roof.closeSubpath()
            context.fill(roof, with: .color(tint(Color(red: 0.62, green: 0.16, blue: 0.14))))

            noren(in: context, over: body, stripes: 6, height: h * 0.34, topInset: h * 0.08)
            lanterns(in: context, over: body, radius: w * 0.14, spread: 0.4)
            steam(in: context, top: body.minY - h * 0.7)
        }

        // MARK: - そのほかの場所

        func cafe(in context: GraphicsContext) {
            let w = unit * 0.48
            let h = rect.height * 0.46
            let body = CGRect(x: centerX - w / 2, y: ground - h, width: w, height: h)

            context.fill(Path(body), with: .color(tint(Color(red: 0.90, green: 0.86, blue: 0.78))))

            var awning = Path()
            awning.move(to: CGPoint(x: body.minX - w * 0.08, y: body.minY + h * 0.22))
            awning.addLine(to: CGPoint(x: body.maxX + w * 0.08, y: body.minY + h * 0.22))
            awning.addLine(to: CGPoint(x: body.maxX, y: body.minY))
            awning.addLine(to: CGPoint(x: body.minX, y: body.minY))
            awning.closeSubpath()
            context.fill(awning, with: .color(tint(Color(red: 0.34, green: 0.52, blue: 0.40))))

            let cupW = w * 0.2
            let cup = CGRect(x: centerX - cupW / 2, y: body.midY, width: cupW, height: cupW * 0.9)
            context.fill(Path(roundedRect: cup, cornerRadius: cupW * 0.12), with: .color(tint(.white)))
            steam(in: context, top: cup.minY - h * 0.3)
        }

        func themePark(in context: GraphicsContext) {
            let w = unit * 0.34
            let h = rect.height * 0.62
            let body = CGRect(x: centerX - w / 2, y: ground - h, width: w, height: h)
            context.fill(Path(body), with: .color(tint(Color(red: 0.92, green: 0.90, blue: 0.94))))

            for side in [-1.0, 1.0] {
                let towerW = w * 0.3
                let towerH = h * 1.15
                let tower = CGRect(x: centerX + side * w * 0.55 - towerW / 2,
                                   y: ground - towerH, width: towerW, height: towerH)
                context.fill(Path(tower), with: .color(tint(Color(red: 0.88, green: 0.86, blue: 0.92))))
                spire(in: context, over: tower, color: tint(Color(red: 0.32, green: 0.52, blue: 0.78)))
            }
            spire(in: context, over: body, color: tint(Color(red: 0.82, green: 0.30, blue: 0.36)))
        }

        func liveVenue(in context: GraphicsContext) {
            let w = unit * 0.62
            let h = rect.height * 0.44
            let body = CGRect(x: centerX - w / 2, y: ground - h, width: w, height: h)
            context.fill(Path(body), with: .color(tint(Color(red: 0.22, green: 0.20, blue: 0.30))))

            for index in 0..<3 {
                let x = body.minX + w * (0.25 + Double(index) * 0.25)
                let reach = rect.height * 0.9
                var beam = Path()
                beam.move(to: CGPoint(x: x - unit * 0.01, y: body.minY))
                beam.addLine(to: CGPoint(x: x + unit * 0.01, y: body.minY))
                beam.addLine(to: CGPoint(x: x + unit * 0.09, y: body.minY - reach))
                beam.addLine(to: CGPoint(x: x - unit * 0.09, y: body.minY - reach))
                beam.closeSubpath()
                context.fill(beam, with: .color(tint(Color(red: 0.86, green: 0.62, blue: 1.0)).opacity(0.45)))
            }

            context.fill(
                Path(CGRect(x: body.minX + w * 0.1, y: body.midY, width: w * 0.8, height: h * 0.3)),
                with: .color(tint(Color(red: 0.96, green: 0.82, blue: 0.34)))
            )
        }

        func conventionHall(in context: GraphicsContext) {
            let w = unit * 0.72
            let h = rect.height * 0.42
            let body = CGRect(x: centerX - w / 2, y: ground - h, width: w, height: h)
            context.fill(Path(body), with: .color(tint(Color(red: 0.68, green: 0.70, blue: 0.74))))

            var roof = Path()
            roof.move(to: CGPoint(x: body.minX, y: body.minY))
            roof.addLine(to: CGPoint(x: body.maxX, y: body.minY))
            roof.addLine(to: CGPoint(x: centerX, y: body.minY - h * 0.5))
            roof.closeSubpath()
            context.fill(roof, with: .color(tint(Color(red: 0.52, green: 0.56, blue: 0.62))))

            context.fill(
                Path(CGRect(x: body.minX + w * 0.12, y: body.minY + h * 0.28,
                            width: w * 0.76, height: h * 0.24)),
                with: .color(tint(Color(red: 0.86, green: 0.28, blue: 0.30)))
            )
        }

        // MARK: - 共通の部品

        /// 赤い暖簾。ラーメン屋らしさの中心。
        private func noren(
            in context: GraphicsContext,
            over body: CGRect,
            stripes: Int,
            height: Double,
            topInset: Double = 0
        ) {
            let gap = body.width * 0.008
            let stripeW = (body.width * 0.94 - gap * Double(stripes - 1)) / Double(stripes)

            for index in 0..<stripes {
                let x = body.minX + body.width * 0.03 + Double(index) * (stripeW + gap)
                context.fill(
                    Path(CGRect(x: x, y: body.minY + topInset, width: stripeW, height: height)),
                    with: .color(tint(Color(red: 0.82, green: 0.18, blue: 0.15)))
                )
            }
        }

        /// 赤提灯。
        private func lanterns(
            in context: GraphicsContext,
            over body: CGRect,
            radius: Double,
            spread: Double
        ) {
            for side in [-1.0, 1.0] {
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: centerX + side * body.width * spread - radius / 2,
                        y: body.minY - radius * 1.3,
                        width: radius,
                        height: radius * 1.3
                    )),
                    with: .color(tint(Color(red: 0.90, green: 0.25, blue: 0.18)))
                )
            }
        }

        private func spire(in context: GraphicsContext, over rect: CGRect, color: Color) {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.minY - rect.width * 0.8))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.closeSubpath()
            context.fill(path, with: .color(color))
        }

        /// 湯気。小さすぎると潰れるので、ある程度の大きさがあるときだけ描く。
        private func steam(in context: GraphicsContext, top: Double) {
            guard showsSteam, !silhouette, unit > 90 else { return }

            for index in 0..<3 {
                let offset = Double(index - 1) * unit * 0.07
                var path = Path()
                path.move(to: CGPoint(x: centerX + offset, y: top + unit * 0.09))
                path.addQuadCurve(
                    to: CGPoint(x: centerX + offset, y: top),
                    control: CGPoint(x: centerX + offset + unit * 0.05, y: top + unit * 0.045)
                )
                context.stroke(path, with: .color(.white.opacity(0.5)), lineWidth: max(1.5, unit * 0.01))
            }
        }
    }
}
