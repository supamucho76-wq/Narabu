import SwiftUI
import UIKit

/// 警備員をやり過ごす。
///
/// 見られていない隙だけ前に詰める。見られている最中に動くと見つかる。
/// 押している間だけ進み、赤くなったら手を離す。
///
/// **振り向く前に必ず予告が入る。** 予告なしに切り替わると、
/// 押していた指が間に合わず理不尽になるため。
struct HideGame: View {
    let seconds: Double
    let onFinish: (Bool) -> Void

    /// 進みきるのに必要な、忍び足の合計時間。
    private static let requiredCreep: Double = 2.6

    /// 警備員のふるまいが一巡する長さ。
    private static let cycle: Double = 2.8
    /// この時刻から「振り向くぞ」の予告に入る。
    private static let warningStart: Double = 1.2
    /// この時刻から実際に見られている。
    private static let watchStart: Double = 1.9

    /// 警備員のようす。
    private enum Guard {
        /// よそを向いている。進める。
        case away
        /// 振り向こうとしている。まだ捕まらないが、離す時間。
        case turning
        /// こちらを見ている。動くと見つかる。
        case watching

        var isSafe: Bool { self != .watching }

        var symbolName: String {
            switch self {
            case .away: "eye.slash.fill"
            case .turning: "exclamationmark.triangle.fill"
            case .watching: "eye.fill"
            }
        }

        var label: String {
            switch self {
            case .away: "いまなら進める"
            case .turning: "振り向くぞ"
            case .watching: "見られている"
            }
        }

        var color: Color {
            switch self {
            case .away: Color(red: 0.42, green: 0.72, blue: 0.52)
            case .turning: Color(red: 0.92, green: 0.68, blue: 0.18)
            case .watching: Color(red: 0.88, green: 0.26, blue: 0.22)
            }
        }
    }

    @State private var creep: Double = 0
    @State private var isMoving = false
    @State private var lastUpdate = Date()
    @State private var startedAt = Date()
    @State private var isDone = false
    /// 予告に入った瞬間に一度だけ震わせるための印。
    @State private var lastWarnedCycle = -1

    var body: some View {
        VStack(spacing: 14) {
            MissionParts.stage(height: 190) {
                TimelineView(.animation) { timeline in
                    let state = guardState(at: timeline.date)

                    VStack(spacing: 10) {
                        Image(systemName: state.symbolName)
                            .font(.system(size: 38))
                            .foregroundStyle(state.color)
                            // 振り向く手前だけ、そわそわさせる。
                            .scaleEffect(state == .turning ? 1.12 : 1)
                            .animation(.easeOut(duration: 0.12), value: state == .turning)

                        Text(state.label)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.ink)

                        // 振り向くまでの猶予。減っていくのが目で見える。
                        MissionParts.track(
                            ratio: turnRatio(at: timeline.date),
                            tint: state.color,
                            height: 5
                        )
                        .padding(.horizontal, 40)

                        MissionParts.track(
                            ratio: creep / Self.requiredCreep,
                            tint: state.isSafe ? AppTheme.stamp : state.color
                        )
                        .padding(.horizontal, 30)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task(id: Int(timeline.date.timeIntervalSince(startedAt) * 20)) {
                        advance(at: timeline.date, state: state)
                    }
                }
            }

            // 押している間だけ進む。離すのは自分の判断。
            Text("押している間だけ進む。黄色になったら離す")
                .font(.caption)
                .foregroundStyle(AppTheme.inkSecondary)

            Rectangle()
                .fill(isMoving ? AppTheme.stamp : AppTheme.ink)
                .frame(maxWidth: .infinity, minHeight: 64)
                .overlay {
                    Text(isMoving ? "進んでいる" : "押して進む")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isMoving {
                                isMoving = true
                                lastUpdate = Date()
                            }
                        }
                        .onEnded { _ in isMoving = false }
                )

            MissionParts.countdown(seconds: seconds) { finish(false) }
        }
        .onAppear {
            startedAt = Date()
            lastUpdate = Date()
        }
    }

    // MARK: - 警備員

    private func phase(at date: Date) -> Double {
        date.timeIntervalSince(startedAt).truncatingRemainder(dividingBy: Self.cycle)
    }

    private func guardState(at date: Date) -> Guard {
        let t = phase(at: date)
        if t >= Self.watchStart { return .watching }
        if t >= Self.warningStart { return .turning }
        return .away
    }

    /// 振り向くまでの残り。安全なあいだ1から0へ落ちていく。
    private func turnRatio(at date: Date) -> Double {
        let t = phase(at: date)
        guard t < Self.watchStart else { return 0 }
        return 1 - t / Self.watchStart
    }

    // MARK: - 進行

    private func advance(at date: Date, state: Guard) {
        guard !isDone else { return }

        // 予告に入った最初の一度だけ、指に知らせる。
        let cycleIndex = Int(date.timeIntervalSince(startedAt) / Self.cycle)
        if state == .turning, lastWarnedCycle != cycleIndex {
            lastWarnedCycle = cycleIndex
            if isMoving { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
        }

        let elapsed = date.timeIntervalSince(lastUpdate)
        lastUpdate = date
        guard isMoving else { return }

        guard state.isSafe else {
            // 見られている最中に動くと、そこで終わり。
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            finish(false)
            return
        }

        // 振り向く手前は忍び足になるので、進みが鈍る。
        creep += elapsed * (state == .turning ? 0.5 : 1)
        if creep >= Self.requiredCreep { finish(true) }
    }

    private func finish(_ success: Bool) {
        guard !isDone else { return }
        isDone = true
        isMoving = false
        onFinish(success)
    }
}
