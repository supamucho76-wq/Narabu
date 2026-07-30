import SwiftUI

/// ステージをクリアしたときに出る画面。
struct StageClearView: View {
    let result: StageClearResult
    let nextStage: Stage
    let onContinue: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color(red: 0.10, green: 0.09, blue: 0.11).ignoresSafeArea()

            RadialGradient(
                colors: [Color(red: 0.98, green: 0.82, blue: 0.36).opacity(0.28), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 460
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()

                VStack(spacing: 6) {
                    Text("CLEAR")
                        .font(.system(size: 15, weight: .black))
                        .tracking(8)
                        .foregroundStyle(Color(red: 0.98, green: 0.86, blue: 0.44))
                    Text(result.stage.name)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text("\(result.stage.queueLength.formatted())人を抜けた")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .scaleEffect(appeared ? 1 : 0.9)
                .opacity(appeared ? 1 : 0)

                rewards

                Spacer()

                VStack(spacing: 10) {
                    Text("次は「\(nextStage.name)」\(nextStage.queueLength.formatted())人")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.65))

                    Button(action: onContinue) {
                        Text("次の行列へ")
                            .font(.headline)
                            .foregroundStyle(Color(red: 0.12, green: 0.10, blue: 0.10))
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(Color(red: 0.98, green: 0.86, blue: 0.44))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 28)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6)) { appeared = true }
        }
    }

    private var rewards: some View {
        VStack(spacing: 8) {
            rewardRow(
                symbol: "circle.hexagongrid.fill",
                title: "コイン",
                detail: "+\(result.coins.formatted())",
                tint: Color(red: 0.98, green: 0.80, blue: 0.34)
            )
            rewardRow(
                symbol: "ticket.fill",
                title: "ガチャチケット",
                detail: "+\(result.gachaTickets)",
                tint: Color(red: 0.62, green: 0.78, blue: 0.98)
            )
            if let equipment = result.equipment {
                rewardRow(
                    symbol: equipment.symbolName,
                    title: "装備「\(equipment.name)」",
                    detail: equipment.detail,
                    tint: Color(red: 0.72, green: 0.92, blue: 0.66)
                )
            }
            if let skill = result.skill {
                rewardRow(
                    symbol: skill.symbolName,
                    title: "スキル「\(skill.name)」",
                    detail: skill.detail,
                    tint: Color(red: 0.92, green: 0.68, blue: 0.94)
                )
            }
            rewardRow(
                symbol: "shippingbox.fill",
                title: "記念品",
                detail: result.souvenir.name,
                tint: Color(red: 0.86, green: 0.84, blue: 0.80)
            )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
        .animation(.easeOut(duration: 0.5).delay(0.2), value: appeared)
    }

    private func rewardRow(symbol: String, title: String, detail: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .foregroundStyle(tint)
                .frame(width: 28)
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
            Spacer()
            Text(detail)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
