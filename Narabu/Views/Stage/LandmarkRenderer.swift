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
        case 7: shape.grandRamenShop(in: canvas)
        case 8: shape.sneakerStore(in: canvas)
        case 9: shape.securityGate(in: canvas)
        case 10: shape.summitToilet(in: canvas)
        case 11: shape.spaceport(in: canvas)
        case 12: shape.heavenGate(in: canvas)
        case 13: shape.rebirthCounter(in: canvas)
        case 14: shape.gameShop(in: canvas)
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

        // MARK: - だんだんおかしくなっていく行き先

        /// 限定スニーカーの店。シャッターと巨大な靴の看板。
        func sneakerStore(in context: GraphicsContext) {
            let w = unit * 0.56
            let h = rect.height * 0.5
            let body = CGRect(x: centerX - w / 2, y: ground - h, width: w, height: h)

            context.fill(Path(body), with: .color(tint(Color(red: 0.18, green: 0.18, blue: 0.22))))

            // 半分だけ開いたシャッター
            for index in 0..<5 {
                let y = body.minY + h * 0.30 + Double(index) * h * 0.09
                context.fill(
                    Path(CGRect(x: body.minX + w * 0.08, y: y, width: w * 0.84, height: h * 0.05)),
                    with: .color(tint(Color(red: 0.60, green: 0.62, blue: 0.66)))
                )
            }

            // 屋根の上の靴の看板
            let shoe = CGRect(x: centerX - w * 0.28, y: body.minY - h * 0.34,
                              width: w * 0.56, height: h * 0.26)
            var sole = Path()
            sole.move(to: CGPoint(x: shoe.minX, y: shoe.maxY))
            sole.addLine(to: CGPoint(x: shoe.maxX, y: shoe.maxY))
            sole.addLine(to: CGPoint(x: shoe.maxX, y: shoe.midY))
            sole.addQuadCurve(to: CGPoint(x: shoe.minX + shoe.width * 0.3, y: shoe.minY),
                              control: CGPoint(x: shoe.midX, y: shoe.minY))
            sole.addLine(to: CGPoint(x: shoe.minX, y: shoe.midY))
            sole.closeSubpath()
            context.fill(sole, with: .color(tint(Color(red: 0.94, green: 0.28, blue: 0.24))))
        }

        /// 保安検査。ゲートとトレー。
        func securityGate(in context: GraphicsContext) {
            let w = unit * 0.5
            let h = rect.height * 0.56
            let thickness = w * 0.16

            // 門型のゲート
            for side in [-1.0, 1.0] {
                context.fill(
                    Path(CGRect(x: centerX + side * (w / 2) - thickness / 2,
                                y: ground - h, width: thickness, height: h)),
                    with: .color(tint(Color(red: 0.78, green: 0.80, blue: 0.84)))
                )
            }
            context.fill(
                Path(CGRect(x: centerX - w / 2 - thickness / 2, y: ground - h,
                            width: w + thickness, height: thickness)),
                with: .color(tint(Color(red: 0.62, green: 0.66, blue: 0.72)))
            )

            // 通過を知らせる緑の灯り
            let r = thickness * 0.5
            context.fill(
                Path(ellipseIn: CGRect(x: centerX - r / 2, y: ground - h + thickness * 1.3,
                                       width: r, height: r)),
                with: .color(tint(Color(red: 0.36, green: 0.82, blue: 0.46)))
            )

            // ベルトコンベアとトレー
            let belt = CGRect(x: centerX - unit * 0.34, y: ground - h * 0.18,
                              width: unit * 0.68, height: h * 0.10)
            context.fill(Path(belt), with: .color(tint(Color(red: 0.32, green: 0.34, blue: 0.38))))
            for index in 0..<3 {
                context.fill(
                    Path(CGRect(x: belt.minX + belt.width * (0.08 + Double(index) * 0.32),
                                y: belt.minY - belt.height * 0.55,
                                width: belt.width * 0.2, height: belt.height * 0.55)),
                    with: .color(tint(Color(red: 0.56, green: 0.44, blue: 0.34)))
                )
            }
        }

        /// 富士山頂のトイレ。山の上に小屋がひとつ。
        func summitToilet(in context: GraphicsContext) {
            // 山
            var mountain = Path()
            mountain.move(to: CGPoint(x: centerX - unit * 0.5, y: ground))
            mountain.addLine(to: CGPoint(x: centerX, y: ground - rect.height * 0.62))
            mountain.addLine(to: CGPoint(x: centerX + unit * 0.5, y: ground))
            mountain.closeSubpath()
            context.fill(mountain, with: .color(tint(Color(red: 0.36, green: 0.40, blue: 0.50))))

            // 冠雪
            var snow = Path()
            snow.move(to: CGPoint(x: centerX - unit * 0.17, y: ground - rect.height * 0.41))
            snow.addLine(to: CGPoint(x: centerX, y: ground - rect.height * 0.62))
            snow.addLine(to: CGPoint(x: centerX + unit * 0.17, y: ground - rect.height * 0.41))
            snow.closeSubpath()
            context.fill(snow, with: .color(tint(Color(red: 0.96, green: 0.97, blue: 1.0))))

            // 頂上の小屋。こんなところにも列がある。
            let w = unit * 0.16
            let h = rect.height * 0.16
            let hut = CGRect(x: centerX - w / 2, y: ground - rect.height * 0.58 - h * 0.2,
                             width: w, height: h)
            context.fill(Path(hut), with: .color(tint(Color(red: 0.70, green: 0.68, blue: 0.64))))
            var roof = Path()
            roof.move(to: CGPoint(x: hut.minX - w * 0.16, y: hut.minY))
            roof.addLine(to: CGPoint(x: hut.maxX + w * 0.16, y: hut.minY))
            roof.addLine(to: CGPoint(x: centerX, y: hut.minY - h * 0.4))
            roof.closeSubpath()
            context.fill(roof, with: .color(tint(Color(red: 0.42, green: 0.38, blue: 0.36))))
        }

        /// 宇宙船の搭乗口。ロケットとタラップ。
        func spaceport(in context: GraphicsContext) {
            let w = unit * 0.22
            let h = rect.height * 0.72
            let body = CGRect(x: centerX - w / 2, y: ground - h, width: w, height: h)

            context.fill(
                Path(roundedRect: body, cornerRadius: w * 0.35),
                with: .color(tint(Color(red: 0.92, green: 0.93, blue: 0.96)))
            )

            // 先端
            var nose = Path()
            nose.move(to: CGPoint(x: body.minX, y: body.minY + h * 0.06))
            nose.addLine(to: CGPoint(x: centerX, y: body.minY - h * 0.2))
            nose.addLine(to: CGPoint(x: body.maxX, y: body.minY + h * 0.06))
            nose.closeSubpath()
            context.fill(nose, with: .color(tint(Color(red: 0.86, green: 0.26, blue: 0.22))))

            // 窓
            let r = w * 0.4
            context.fill(
                Path(ellipseIn: CGRect(x: centerX - r / 2, y: body.minY + h * 0.22,
                                       width: r, height: r)),
                with: .color(tint(Color(red: 0.42, green: 0.72, blue: 0.92)))
            )

            // 搭乗タラップ
            var ramp = Path()
            ramp.move(to: CGPoint(x: body.maxX, y: ground - h * 0.3))
            ramp.addLine(to: CGPoint(x: centerX + unit * 0.36, y: ground))
            ramp.addLine(to: CGPoint(x: centerX + unit * 0.30, y: ground))
            ramp.addLine(to: CGPoint(x: body.maxX, y: ground - h * 0.38))
            ramp.closeSubpath()
            context.fill(ramp, with: .color(tint(Color(red: 0.58, green: 0.60, blue: 0.66))))
        }

        /// 天国の門。柱と、その上の輪。
        func heavenGate(in context: GraphicsContext) {
            let w = unit * 0.46
            let h = rect.height * 0.6
            let pillar = w * 0.15

            for side in [-1.0, 1.0] {
                context.fill(
                    Path(CGRect(x: centerX + side * (w / 2) - pillar / 2,
                                y: ground - h, width: pillar, height: h)),
                    with: .color(tint(Color(red: 0.98, green: 0.97, blue: 0.90)))
                )
            }

            // まぐさ
            context.fill(
                Path(CGRect(x: centerX - w / 2 - pillar, y: ground - h,
                            width: w + pillar * 2, height: pillar * 0.9)),
                with: .color(tint(Color(red: 0.94, green: 0.90, blue: 0.78)))
            )

            // 門の上に浮かぶ輪
            let ring = w * 0.42
            context.stroke(
                Path(ellipseIn: CGRect(x: centerX - ring / 2, y: ground - h - ring * 0.9,
                                       width: ring, height: ring * 0.42)),
                with: .color(tint(Color(red: 1.0, green: 0.90, blue: 0.42))),
                lineWidth: max(2, ring * 0.14)
            )

            // 門の内側から漏れる光
            context.fill(
                Path(CGRect(x: centerX - w / 2 + pillar / 2, y: ground - h + pillar,
                            width: w - pillar, height: h - pillar)),
                with: .color(tint(Color(red: 1.0, green: 0.98, blue: 0.84)).opacity(silhouette ? 1 : 0.55))
            )
        }

        /// 転生の窓口。役所のカウンターと番号表示。
        func rebirthCounter(in context: GraphicsContext) {
            let w = unit * 0.62
            let h = rect.height * 0.46
            let body = CGRect(x: centerX - w / 2, y: ground - h, width: w, height: h)

            context.fill(Path(body), with: .color(tint(Color(red: 0.80, green: 0.78, blue: 0.72))))

            // カウンター
            context.fill(
                Path(CGRect(x: body.minX - w * 0.06, y: ground - h * 0.28,
                            width: w * 1.12, height: h * 0.12)),
                with: .color(tint(Color(red: 0.52, green: 0.42, blue: 0.32)))
            )

            // 番号表示。あと何人かは分からない。
            let board = CGRect(x: centerX - w * 0.22, y: body.minY + h * 0.14,
                               width: w * 0.44, height: h * 0.26)
            context.fill(Path(board), with: .color(tint(Color(red: 0.14, green: 0.16, blue: 0.20))))
            for index in 0..<3 {
                context.fill(
                    Path(CGRect(x: board.minX + board.width * (0.14 + Double(index) * 0.26),
                                y: board.minY + board.height * 0.26,
                                width: board.width * 0.14, height: board.height * 0.48)),
                    with: .color(tint(Color(red: 0.96, green: 0.42, blue: 0.28)))
                )
            }
        }

        /// ゲームショップ。並ぶために並ぶ場所。
        func gameShop(in context: GraphicsContext) {
            let w = unit * 0.56
            let h = rect.height * 0.48
            let body = CGRect(x: centerX - w / 2, y: ground - h, width: w, height: h)

            context.fill(Path(body), with: .color(tint(Color(red: 0.24, green: 0.26, blue: 0.34))))

            // ショーウィンドウ
            context.fill(
                Path(CGRect(x: body.minX + w * 0.08, y: body.minY + h * 0.34,
                            width: w * 0.84, height: h * 0.44)),
                with: .color(tint(Color(red: 0.72, green: 0.84, blue: 0.94)))
            )

            // 窓の中に並んでいる、小さな人の影
            for index in 0..<5 {
                let personWidth = w * 0.055
                let x = body.minX + w * 0.16 + Double(index) * w * 0.16
                context.fill(
                    Path(roundedRect: CGRect(x: x, y: body.minY + h * 0.48,
                                             width: personWidth, height: h * 0.26),
                         cornerRadius: personWidth * 0.4),
                    with: .color(tint(Color(red: 0.30, green: 0.32, blue: 0.40)))
                )
            }

            // 看板
            context.fill(
                Path(CGRect(x: body.minX + w * 0.14, y: body.minY - h * 0.2,
                            width: w * 0.72, height: h * 0.2)),
                with: .color(tint(Color(red: 0.96, green: 0.78, blue: 0.28)))
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
