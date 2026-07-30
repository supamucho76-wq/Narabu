import SwiftUI
import UIKit

/// ガチャを引く画面。
///
/// 引く前は丼が震え、光が広がり、中からアイテムが出る。
/// 等級が高いほど、ためが長く光も強くなる。
struct GachaView: View {
    enum Mode {
        /// 初回だけの5連。
        case starter
        /// 1時間ごとの1回。
        case free
        /// チケットを使って引く1回。
        case ticket

        var drawCount: Int {
            switch self {
            case .starter: GachaCatalog.starterDrawCount
            case .free, .ticket: 1
            }
        }

        var title: String {
            switch self {
            case .starter: "スタートダッシュ5連ガチャ"
            case .free: "無料ガチャ"
            case .ticket: "チケットガチャ"
            }
        }

        var drawLabel: String {
            switch self {
            case .starter: "5回引く"
            case .free, .ticket: "1回引く"
            }
        }

        var costLabel: String {
            switch self {
            case .starter, .free: "無料"
            case .ticket: "チケット1枚"
            }
        }
    }

    private enum Phase {
        case ready
        case shaking
        case revealed
        case summary
    }

    let mode: Mode
    /// 引く処理は呼び出し側が持つ。ここでは結果を見せるだけ。
    let onDraw: () -> [GachaItem]
    let onFinish: () -> Void

    @State private var phase: Phase = .ready
    @State private var results: [GachaItem] = []
    @State private var revealIndex = 0
    @State private var shake = false
    @State private var burst = false

    private var current: GachaItem? {
        results.indices.contains(revealIndex) ? results[revealIndex] : nil
    }

    var body: some View {
        ZStack {
            background

            switch phase {
            case .ready:
                readyPanel
            case .shaking, .revealed:
                revealPanel
            case .summary:
                summaryPanel
            }
        }
    }

    // MARK: - 背景

    private var background: some View {
        ZStack {
            Color(red: 0.10, green: 0.08, blue: 0.09).ignoresSafeArea()

            if let current, phase == .revealed {
                RadialGradient(
                    colors: [current.rarity.color.opacity(0.55 * current.rarity.glowStrength), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 420
                )
                .ignoresSafeArea()
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.4), value: phase)
    }

    // MARK: - 引く前

    private var readyPanel: some View {
        VStack(spacing: 26) {
            Spacer()

            VStack(spacing: 8) {
                Text(mode.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("乗り物が出ます。列をごぼう抜きできます。")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }

            capsule(tint: Color(red: 0.94, green: 0.86, blue: 0.62))
                .frame(width: 150, height: 150)

            rateTable

            Spacer()

            VStack(spacing: 8) {
                Text(mode.costLabel)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(red: 0.12, green: 0.10, blue: 0.10))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.94, green: 0.86, blue: 0.62))
                    .clipShape(Capsule())

                Button(action: startDrawing) {
                    Text(mode.drawLabel)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color(red: 0.12, green: 0.10, blue: 0.10))
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(Color(red: 0.94, green: 0.86, blue: 0.62))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 28)
    }

    /// 何が出るのかが分かるように、確率も見せておく。
    private var rateTable: some View {
        VStack(spacing: 5) {
            ForEach(GachaCatalog.items) { item in
                HStack(spacing: 8) {
                    Text(item.rarity.label)
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(item.rarity.color)
                        .frame(width: 30, alignment: .leading)
                    Image(systemName: item.symbolName)
                        .font(.system(size: 11))
                        .frame(width: 18)
                    Text(item.name)
                        .font(.caption2)
                    Spacer()
                    Text(item.summary)
                        .font(.caption2.weight(.medium))
                    Text(item.dropRate.formatted(.percent.precision(.fractionLength(0))))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 38, alignment: .trailing)
                }
                .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(14)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - 排出中

    private var revealPanel: some View {
        VStack(spacing: 22) {
            Spacer()

            if mode.drawCount > 1 {
                Text("\(revealIndex + 1) / \(results.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5))
            }

            ZStack {
                if phase == .revealed, let current {
                    glow(for: current.rarity)
                }

                capsule(tint: current?.rarity.color ?? .white)
                    .frame(width: 170, height: 170)
                    .rotationEffect(.degrees(shake ? 5 : -5))
                    .scaleEffect(burst ? 1.18 : 1)
            }
            .frame(height: 230)

            if phase == .revealed, let current {
                itemPlate(current)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            } else {
                Color.clear.frame(height: 120)
            }

            Spacer()

            if phase == .revealed {
                Button(action: advance) {
                    Text(revealIndex + 1 < results.count ? "次へ" : "結果を見る")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                        }
                }
            } else {
                Color.clear.frame(height: 52)
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 28)
        .contentShape(Rectangle())
        .onTapGesture { if phase == .revealed { advance() } }
    }

    private func itemPlate(_ item: GachaItem) -> some View {
        VStack(spacing: 6) {
            Text(item.rarity.label)
                .font(.system(size: 13, weight: .black))
                .tracking(2)
                .foregroundStyle(item.rarity.isRainbow ? AnyShapeStyle(rainbow) : AnyShapeStyle(item.rarity.color))

            Text(item.name)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)

            Text(item.summary)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(item.rarity.color)
        }
    }

    // MARK: - 結果一覧

    private var summaryPanel: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("獲得アイテム")
                .font(.headline)
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                ForEach(Array(results.enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 12) {
                        Image(systemName: item.symbolName)
                            .font(.system(size: 16))
                            .frame(width: 26)
                        Text(item.rarity.label)
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(item.rarity.color)
                            .frame(width: 32, alignment: .leading)
                        Text(item.name)
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text(item.summary)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }

            Spacer()

            Button(action: onFinish) {
                Text("行列へ戻る")
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.12, green: 0.10, blue: 0.10))
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Color(red: 0.94, green: 0.86, blue: 0.62))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 28)
    }

    // MARK: - 部品

    /// ラーメン屋なので、カプセルではなく丼が出てくる。
    private func capsule(tint: Color) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.9), tint.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Circle()
                .strokeBorder(.white.opacity(0.5), lineWidth: 3)
            Image(systemName: "takeoutbag.and.cup.and.straw.fill")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(Color(red: 0.14, green: 0.11, blue: 0.11).opacity(0.75))
        }
    }

    private func glow(for rarity: GachaRarity) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { ring in
                Circle()
                    .strokeBorder(
                        rarity.isRainbow ? AnyShapeStyle(rainbow) : AnyShapeStyle(rarity.color),
                        lineWidth: 2
                    )
                    .frame(width: 190 + Double(ring) * 46 * rarity.glowStrength)
                    .opacity(0.55 - Double(ring) * 0.16)
            }
        }
        .scaleEffect(burst ? 1.1 : 0.9)
        .animation(.easeOut(duration: 0.5), value: burst)
    }

    private var rainbow: AngularGradient {
        AngularGradient(
            colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
            center: .center
        )
    }

    // MARK: - 進行

    private func startDrawing() {
        results = onDraw()
        guard !results.isEmpty else {
            onFinish()
            return
        }
        revealIndex = 0
        reveal()
    }

    private func reveal() {
        guard let item = current else { return }

        phase = .shaking
        burst = false
        shake = false

        // 等級が高いほど長く震えてから開く。
        withAnimation(.easeInOut(duration: 0.09).repeatForever(autoreverses: true)) {
            shake = true
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        Task {
            try? await Task.sleep(for: .seconds(item.rarity.buildUpDuration))

            withAnimation(.spring(duration: 0.45)) {
                shake = false
                burst = true
                phase = .revealed
            }
            UINotificationFeedbackGenerator().notificationOccurred(
                item.rarity.glowStrength > 0.5 ? .success : .warning
            )
        }
    }

    private func advance() {
        if revealIndex + 1 < results.count {
            revealIndex += 1
            reveal()
        } else if mode.drawCount > 1 {
            withAnimation { phase = .summary }
        } else {
            onFinish()
        }
    }
}
