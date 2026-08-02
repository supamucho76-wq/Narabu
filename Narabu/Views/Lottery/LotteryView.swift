import SwiftUI
import UIKit

/// ミッションに成功したあとの抽選を見せる画面。
///
/// 3つの提灯が回り、2つ揃うと煽りに入る。**そこから外れることのほうが多い。**
/// 外れても腕で稼いだぶんは必ずもらえるので、待たされること自体は罰にならない。
struct LotteryView: View {
    let lottery: Lottery
    /// 上乗せ前の人数。画面に出して、上乗せ後との差を見せる。
    let basePeople: Int
    let onFinish: (Lottery.Result) -> Void

    @Environment(SoundPlayer.self) private var sound

    /// 出目。0〜6の7種類。
    private static let faceCount = 7

    private enum Phase {
        case spinning
        case reach
        case settled
    }

    @State private var phase: Phase = .spinning
    @State private var stoppedReels = 0
    @State private var startedAt = Date()
    /// 煽りの盛り上がり。0から1へ。背景と震えの強さに使う。
    @State private var heat: Double = 0
    @State private var hasFinished = false

    /// 揃える出目。左と中は必ずこれになる。
    private var winningFace: Int { 6 }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 26) {
                Text(phase == .reach ? "リーチ！" : "抽選中")
                    .font(.system(size: 15, weight: .black))
                    .tracking(6)
                    .foregroundStyle(.white.opacity(phase == .spinning ? 0.55 : 1))

                reels

                if phase == .settled {
                    verdict
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 24)
        }
        .task { await run() }
    }

    // MARK: - 背景

    private var background: some View {
        ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()

            // 煽るほど画面が焼ける。
            RadialGradient(
                colors: [lottery.result.color.opacity(0.55 * heat), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 460
            )
            .ignoresSafeArea()

            if phase == .reach || phase == .settled {
                TimelineView(.animation) { timeline in
                    let t = timeline.date.timeIntervalSince(startedAt)
                    // 放射状に走る光。速さは盛り上がりに比例する。
                    Canvas { context, size in
                        let center = CGPoint(x: size.width / 2, y: size.height / 2)
                        let spokes = 18

                        for index in 0..<spokes {
                            let angle = Double(index) / Double(spokes) * .pi * 2 + t * (0.6 + heat * 2.4)
                            var path = Path()
                            path.move(to: center)
                            path.addLine(to: CGPoint(
                                x: center.x + cos(angle) * size.height,
                                y: center.y + sin(angle) * size.height
                            ))
                            context.stroke(
                                path,
                                with: .color(lottery.result.color.opacity(0.10 * heat)),
                                lineWidth: 26
                            )
                        }
                    }
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }
            }
        }
    }

    // MARK: - 出目

    private var reels: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(startedAt)

            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { index in
                    reel(index: index, at: t)
                }
            }
            // 煽っているあいだ、画面ごと小刻みに震える。
            .offset(x: sin(t * 42) * heat * 5)
        }
    }

    private func reel(index: Int, at t: Double) -> some View {
        let isStopped = index < stoppedReels
        let face = isStopped ? settledFace(index) : spinningFace(index: index, at: t)
        // 最後の1枚は、煽りのあいだだけゆっくり回る。
        let isSlow = index == 2 && phase == .reach

        return Text("\(face + 1)")
            .font(.system(size: 60, weight: .black, design: .rounded))
            .foregroundStyle(isStopped ? lottery.result.color : .white)
            .frame(width: 88, height: 116)
            .background(.white.opacity(isStopped ? 0.14 : 0.07))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isStopped ? lottery.result.color.opacity(0.9) : .white.opacity(0.2),
                        lineWidth: isStopped ? 3 : 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .scaleEffect(isSlow ? 1 + sin(t * 6) * 0.05 : 1)
    }

    /// 回っているあいだの見かけの出目。
    private func spinningFace(index: Int, at t: Double) -> Int {
        // 煽りに入ったら最後の1枚だけ速度を落として、じらす。
        let speed = (index == 2 && phase == .reach) ? 3.5 : 17.0
        return abs(Int(t * speed) + index * 3) % Self.faceCount
    }

    /// 止まったあとの出目。
    private func settledFace(_ index: Int) -> Int {
        guard index == 2 else { return winningFace }
        // 当たりなら揃える。外れなら1つ手前で止めて、惜しく見せる。
        return lottery.result == .miss
            ? (winningFace + Self.faceCount - 1) % Self.faceCount
            : winningFace
    }

    // MARK: - 結果

    private var verdict: some View {
        VStack(spacing: 8) {
            Text(lottery.result.headline)
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(lottery.result.color)

            if lottery.result == .miss {
                Text("\(basePeople)人 前へ")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.75))
            } else {
                HStack(spacing: 8) {
                    Text("\(basePeople)")
                        .strikethrough()
                        .foregroundStyle(.white.opacity(0.45))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(.white.opacity(0.45))
                    Text("\(basePeople * lottery.result.multiplier)人")
                        .foregroundStyle(lottery.result.color)
                }
                .font(.system(size: 22, weight: .black, design: .rounded))
            }
        }
    }

    // MARK: - 進行

    private func run() async {
        startedAt = Date()

        // 揃わない回は手早く終える。毎回同じだけ待たされると、ただの邪魔になる。
        let isQuick = !lottery.showsReach

        try? await Task.sleep(for: .seconds(isQuick ? 0.40 : 0.5))
        stopReel()
        try? await Task.sleep(for: .seconds(isQuick ? 0.16 : 0.28))
        stopReel()

        if lottery.showsReach {
            withAnimation(.easeIn(duration: 0.25)) { phase = .reach }
            await tease()
        }

        stopReel()
        settle()

        try? await Task.sleep(for: .seconds(lottery.result == .miss ? 0.6 : 1.3))
        finish()
    }

    private func stopReel() {
        stoppedReels += 1
        sound.play(.tap)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    /// チャンチャンチャン。畳みかけるほど速く、熱くなる。
    private func tease() async {
        let count = lottery.result.chimeCount
        let total = lottery.result.reachDuration

        for step in 0..<count {
            let ratio = Double(step) / Double(max(1, count - 1))
            withAnimation(.easeOut(duration: 0.12)) { heat = 0.3 + ratio * 0.7 }

            sound.play(.chance)
            UIImpactFeedbackGenerator(style: ratio > 0.6 ? .heavy : .medium).impactOccurred()

            // 後半ほど間隔を詰める。等間隔だと煽りにならない。
            let interval = total / Double(count) * (1.5 - ratio * 0.9)
            try? await Task.sleep(for: .seconds(interval))
        }
    }

    private func settle() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.6)) {
            phase = .settled
            heat = lottery.result == .miss ? 0 : 1
        }

        if lottery.result == .miss {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            sound.play(.fail)
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            sound.play(.jackpot)
        }
    }

    /// 二重に返さない。演出が途中で崩れても、必ず一度だけ先へ進む。
    private func finish() {
        guard !hasFinished else { return }
        hasFinished = true
        onFinish(lottery.result)
    }
}
