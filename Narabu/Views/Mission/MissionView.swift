import SwiftUI
import UIKit

/// ミッションを遊ぶ画面。5〜20秒で終わる短いものだけを扱う。
struct MissionView: View {
    let mission: Mission
    /// 成否と、駆け引きで決まった結果を親に返す。列を進めるのは親の仕事。
    let onFinish: (Bool, EncounterResult?) -> Void

    @State private var taps = 0
    @State private var deadline: Date?
    @State private var gaugeTarget: Double = 0.5
    /// 針を止めた時刻。止めるまでは nil。
    @State private var stoppedAt: Date?
    @State private var verdict: Bool?
    /// 駆け引きで出た結果。
    @State private var encounterResult: EncounterResult?

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 18) {
                header

                if let verdict {
                    result(success: verdict)
                } else {
                    content
                }
            }
            .padding(22)
            .background(AppTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 24)
            .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
        }
        .onAppear(perform: start)
    }

    // MARK: - 見出し

    private var header: some View {
        VStack(spacing: 5) {
            Text("ミッション")
                .font(.system(size: 10, weight: .black))
                .tracking(3)
                .foregroundStyle(AppTheme.stamp)
            Text(mission.title)
                .font(.headline)
            Text(mission.instruction)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(AppTheme.ink)
    }

    // MARK: - 中身

    @ViewBuilder
    private var content: some View {
        switch mission.kind {
        case .mash(let targetTaps, let seconds):
            mashGame(target: targetTaps, seconds: seconds)
        case .timing(let width, let speed):
            timingGame(width: width, speed: speed)
        case .encounter(let encounter):
            encounterGame(encounter)
        }
    }

    // MARK: - 連打

    private func mashGame(target: Int, seconds: Double) -> some View {
        VStack(spacing: 14) {
            TimelineView(.periodic(from: .now, by: 0.1)) { timeline in
                let remaining = max(0, (deadline ?? .now).timeIntervalSince(timeline.date))
                VStack(spacing: 8) {
                    Text("\(taps) / \(target)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    progressTrack(ratio: Double(taps) / Double(target))
                    Text(String(format: "残り %.1f秒", remaining))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .task(id: remaining <= 0) {
                    // 時間切れ。連打が足りていなければ失敗。
                    if remaining <= 0, verdict == nil { finish(taps >= target) }
                }
            }

            Button {
                taps += 1
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if taps >= target { finish(true) }
            } label: {
                Text("タップ")
                    .font(.title3.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 70)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.stamp)
        }
        .foregroundStyle(AppTheme.ink)
    }

    // MARK: - タイミング

    /// 針の位置は時刻だけから決まるので、毎フレーム状態を書き換える必要がない。
    private func needlePosition(at date: Date, speed: Double) -> Double {
        let t = date.timeIntervalSince1970 * speed
        // 端で折り返す往復運動。
        return 1 - abs(t.truncatingRemainder(dividingBy: 2) - 1)
    }

    private func timingGame(width: Double, speed: Double) -> some View {
        VStack(spacing: 16) {
            TimelineView(.animation) { timeline in
                let position = needlePosition(at: stoppedAt ?? timeline.date, speed: speed)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(AppTheme.ink.opacity(0.10))

                        Capsule()
                            .fill(AppTheme.stamp.opacity(0.30))
                            .frame(width: geometry.size.width * width)
                            .offset(x: geometry.size.width * (gaugeTarget - width / 2))

                        Capsule()
                            .fill(AppTheme.ink)
                            .frame(width: 4)
                            .offset(x: geometry.size.width * position - 2)
                    }
                }
                .frame(height: 34)
            }

            Button {
                let now = Date()
                stoppedAt = now
                finish(abs(needlePosition(at: now, speed: speed) - gaugeTarget) <= width / 2)
            } label: {
                Text("止める")
                    .font(.title3.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 60)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.stamp)
        }
    }

    // MARK: - 観察して選ぶ

    /// 仕草だけを見せ、そこから読んで行動を決めてもらう。
    /// 正体は書かないし、同じ相手でも結果は毎回ぶれる。
    private func encounterGame(_ encounter: Encounter) -> some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(encounter.observations.enumerated()), id: \.offset) { _, behavior in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "eye")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.stamp)
                            .padding(.top, 2)
                        Text(behavior)
                            .font(.footnote)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.ink.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
                ForEach(EncounterAction.allCases) { action in
                    Button {
                        choose(action, in: encounter)
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: action.symbolName)
                                .font(.system(size: 15))
                            Text(action.label)
                                .font(.system(size: 10, weight: .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .frame(maxWidth: .infinity, minHeight: 54)
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.ink)
                }
            }
        }
        .foregroundStyle(AppTheme.ink)
    }

    private func choose(_ action: EncounterAction, in encounter: Encounter) {
        let result = encounter.resolve(action)
        encounterResult = result
        finish(result.isGood)
    }

    // MARK: - 結果

    @ViewBuilder
    private func result(success: Bool) -> some View {
        if let encounterResult {
            encounterOutcome(encounterResult)
        } else {
            VStack(spacing: 12) {
                Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle")
                    .font(.system(size: 40))
                    .foregroundStyle(success ? AppTheme.stamp : Color.secondary)

                Text(success ? "達成！" : "失敗")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.ink)

                if success {
                    Text("\(mission.reward)人 前へ進んだ　＋\(mission.coins)コイン")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                } else {
                    Text("次のミッションに切り替わります")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// 駆け引きの顛末。何が起きたかを読ませる。
    private func encounterOutcome(_ result: EncounterResult) -> some View {
        VStack(spacing: 12) {
            Text(headline(for: result.grade))
                .font(.system(size: 12, weight: .black))
                .tracking(3)
                .foregroundStyle(tint(for: result.grade))

            Text(result.message)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(AppTheme.ink)

            if result.advance != 0 {
                Text(result.advance > 0 ? "＋\(result.advance)人" : "\(result.advance)人")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(result.advance > 0 ? AppTheme.stamp : .secondary)
            }
        }
    }

    private func headline(for grade: EncounterResult.Grade) -> String {
        switch grade {
        case .triumph: "大成功"
        case .success: "成功"
        case .failure: "失敗"
        case .twist: "予想外"
        }
    }

    private func tint(for grade: EncounterResult.Grade) -> Color {
        switch grade {
        case .triumph: AppTheme.stamp
        case .success: Color(red: 0.36, green: 0.62, blue: 0.86)
        case .failure: Color(red: 0.55, green: 0.55, blue: 0.58)
        case .twist: Color(red: 0.72, green: 0.44, blue: 0.88)
        }
    }

    // MARK: - 進行

    private func start() {
        if case .mash(_, let seconds) = mission.kind {
            deadline = Date().addingTimeInterval(seconds)
        }
        if case .timing = mission.kind {
            // 当たり範囲は毎回ずらす。真ん中で止める癖がつかないように。
            gaugeTarget = 0.25 + QueueEngine.unitRandom(mission.id.hashValue, salt: 0x9A77) * 0.5
        }
    }

    private func finish(_ success: Bool) {
        guard verdict == nil else { return }
        verdict = success
        if stoppedAt == nil { stoppedAt = Date() }

        UINotificationFeedbackGenerator().notificationOccurred(success ? .success : .warning)

        // 顛末を読ませたいので、駆け引きだけ少し長めに見せる。
        let pause = encounterResult != nil ? 2.4 : (success ? 1.2 : 1.6)

        Task {
            try? await Task.sleep(for: .seconds(pause))
            onFinish(success, encounterResult)
        }
    }

    private func progressTrack(ratio: Double) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(AppTheme.ink.opacity(0.10))
                Capsule()
                    .fill(AppTheme.stamp)
                    .frame(width: geometry.size.width * min(1, max(0, ratio)))
            }
        }
        .frame(height: 6)
    }
}
