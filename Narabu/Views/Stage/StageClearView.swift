import SwiftUI

/// 行列の先にたどり着いたときの画面。
///
/// 「クリア」と数字を出すだけでは、どこに着いたのか分からない。
/// たどり着いた場所を絵と言葉で見せてから報酬を渡し、
/// 最後に次の行き先を影で予告して、次への引きを残す。
struct StageClearView: View {
    let result: StageClearResult
    let nextStage: Stage
    let onContinue: () -> Void

    @State private var phase = Phase.arriving

    private enum Phase {
        /// 着いた瞬間。
        case arriving
        /// 着いた先で言われた一言。
        case punchline
        /// 受け取ったものを見せる。
        case rewards
        /// 次はどこへ。
        case next
    }

    /// このクリアで出るオチ。同じクリアでは変わらない。
    private var punchline: StagePunchline {
        PunchlineCatalog.punchline(
            for: result.stage,
            seed: result.stage.id &* 977 &+ result.coins &+ result.gachaTickets
        )
    }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                switch phase {
                case .arriving: arrival
                case .punchline: punchlineScene
                case .rewards: rewards
                case .next: nextPreview
                }

                Spacer(minLength: 0)
                advanceButton
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 26)
        }
        .onAppear {
            // 着いた瞬間だけ、少し間を置いてから読ませる。
            withAnimation(.easeOut(duration: 0.5)) { phase = .arriving }
        }
    }

    // MARK: - オチ

    /// たどり着いた先で言われる一言。
    ///
    /// **これだけ抜いてきた末に、ここで裏切る。**
    /// 先頭に着いて終わるだけでは、次の行列に並ぶ理由が生まれない。
    private var punchlineScene: some View {
        VStack(spacing: 20) {
            Image(systemName: punchline.symbolName)
                .font(.system(size: 54))
                .foregroundStyle(Color(red: 0.96, green: 0.52, blue: 0.42))

            Text(punchline.headline)
                .font(.system(size: 32, weight: .black))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(punchline.detail)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .transition(.scale(scale: 0.85).combined(with: .opacity))
    }

    private var background: some View {
        ZStack {
            Color(red: 0.10, green: 0.09, blue: 0.11).ignoresSafeArea()
            RadialGradient(
                colors: [Color(red: 0.98, green: 0.82, blue: 0.36).opacity(0.26), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 480
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - 着いた

    private var arrival: some View {
        VStack(spacing: 18) {
            Text("到着")
                .font(.system(size: 13, weight: .black))
                .tracking(9)
                .foregroundStyle(Color(red: 0.98, green: 0.86, blue: 0.44))

            LandmarkView(stage: result.stage)

            VStack(spacing: 10) {
                Text(result.stage.arrivalHeadline)
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(result.stage.arrivalStory)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(result.stage.queueLength.formatted())人を抜いた")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 0.98, green: 0.86, blue: 0.44))
                    .padding(.top, 4)
            }
        }
        .transition(.opacity)
    }

    // MARK: - もらったもの

    private var rewards: some View {
        VStack(spacing: 14) {
            Text("受け取ったもの")
                .font(.system(size: 12, weight: .black))
                .tracking(4)
                .foregroundStyle(Color(red: 0.98, green: 0.86, blue: 0.44))

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
        }
        .transition(.opacity)
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
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - 次はどこへ

    /// 次の行き先を影で見せる。何が待っているかは、着いてからのお楽しみ。
    private var nextPreview: some View {
        VStack(spacing: 18) {
            Text("次の行列")
                .font(.system(size: 12, weight: .black))
                .tracking(4)
                .foregroundStyle(.white.opacity(0.6))

            LandmarkView(stage: nextStage, isSilhouette: true)

            VStack(spacing: 8) {
                Text(nextStage.name)
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(.white)

                Text("\(nextStage.queueLength.formatted())人が並んでいる")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(red: 0.98, green: 0.86, blue: 0.44))

                Text(nextStage.openingNote)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            }
        }
        .transition(.opacity)
    }

    // MARK: - 進む

    private var advanceButton: some View {
        Button {
            switch phase {
            case .arriving:
                withAnimation(.easeInOut(duration: 0.35)) { phase = .punchline }
            case .punchline:
                withAnimation(.easeInOut(duration: 0.35)) { phase = .rewards }
            case .rewards:
                withAnimation(.easeInOut(duration: 0.35)) { phase = .next }
            case .next:
                onContinue()
            }
        } label: {
            Text(buttonTitle)
                .font(.headline)
                .foregroundStyle(Color(red: 0.12, green: 0.10, blue: 0.10))
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(Color(red: 0.98, green: 0.86, blue: 0.44))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(GameButtonStyle())
    }

    private var buttonTitle: String {
        switch phase {
        case .arriving: "店に入る"
        case .punchline: "……受け取る"
        case .rewards: "次はどこへ"
        case .next: "この行列に並ぶ"
        }
    }
}
