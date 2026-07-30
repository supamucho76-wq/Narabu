import SwiftUI
import UIKit

/// 並んでいるあいだ、ずっと表示されている画面。
/// 画面のほとんどは前に並んでいる人たちで埋まっている。
struct QueueView: View {
    @Environment(QueueStore.self) private var store
    @Environment(PurchaseStore.self) private var purchases

    @State private var isShowingCollection = false
    @State private var isShowingPrize = false
    @State private var claimedPrize: CollectedPrize?
    @State private var reaction: String?
    @State private var reactionToken = 0

    var body: some View {
        ZStack {
            AppTheme.sky(tone: store.scenery.skyTone)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 1.2), value: store.scenery.skyTone)

            crowd

            VStack(spacing: 0) {
                conditionsBar
                positionDisplay
                Spacer(minLength: 0)
                reactionToast
                sceneryCaption
                actions
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .foregroundStyle(AppTheme.ink)
        .sheet(isPresented: $isShowingCollection) {
            CollectionView()
        }
        .fullScreenCover(isPresented: $isShowingPrize) {
            if let claimedPrize {
                PrizeRevealView(record: claimedPrize)
            }
        }
        .task {
            store.startTicking()
            await NotificationScheduler.requestAuthorization()
            await rescheduleNotifications()
        }
    }

    // MARK: - 前に並んでいる人たち

    private var crowd: some View {
        QueueCrowdView(
            position: store.position,
            anchorDate: store.state.anchorDate,
            onTapPersonAhead: tapPersonAhead
        )
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - 上部：天気と経過

    private var conditionsBar: some View {
        HStack(spacing: 14) {
            Label(
                store.scenery.isSheltered ? "屋根の下" : store.weather.label,
                systemImage: store.scenery.isSheltered ? "building.2" : store.weather.symbolName
            )

            Spacer()

            Text("\(store.daysInCurrentLap)日目")
            Text("\(store.state.lap)周目")
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(AppTheme.inkSecondary)
        .padding(.top, 6)
    }

    // MARK: - 並び順

    private var positionDisplay: some View {
        VStack(spacing: 0) {
            if store.hasReachedFront {
                PlacardLabel(text: "お呼びしました")
                Text("先頭")
                    .font(.system(size: 52, weight: .light, design: .serif))
            } else {
                Text(store.position, format: .number)
                    .font(.system(size: 56, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.snappy, value: store.position)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                PlacardLabel(text: "人目")
            }
        }
        .padding(.top, 4)
    }

    // MARK: - 叩いたときの反応

    private var reactionToast: some View {
        Group {
            if let reaction {
                Text(reaction)
                    .font(.footnote.weight(.medium))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AppTheme.paper.opacity(0.94))
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(AppTheme.ink.opacity(0.18), lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: reaction)
        .padding(.bottom, 12)
    }

    // MARK: - 景色と前の人

    private var sceneryCaption: some View {
        VStack(spacing: 3) {
            Text(store.scenery.title)
                .font(.caption.weight(.semibold))
            Text(store.personAhead.appearance)
                .font(.caption2)
                .foregroundStyle(AppTheme.inkSecondary)
            Text("\(store.personAhead.behavior)。\(store.personAhead.waitingLabel)。")
                .font(.caption2)
                .foregroundStyle(AppTheme.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 12)
    }

    // MARK: - 操作

    private var actions: some View {
        VStack(spacing: 8) {
            if store.hasReachedFront {
                Button("受け取る") { claim() }
                    .buttonStyle(QuietButtonStyle(emphasized: true))
            } else {
                Button {
                    Task { await skipAhead() }
                } label: {
                    if purchases.isPurchasing {
                        ProgressView()
                    } else {
                        Text("\(PurchaseStore.skipAmount)人抜かす　\(purchases.priceLabel)")
                    }
                }
                .buttonStyle(QuietButtonStyle(emphasized: true))
                .disabled(purchases.isPurchasing)
            }

            HStack(spacing: 8) {
                Button("景品図鑑") { isShowingCollection = true }
                    .buttonStyle(QuietButtonStyle())

                Button("列を抜ける") { leaveQueue() }
                    .buttonStyle(QuietButtonStyle())
            }

            summaryLine
        }
    }

    private var summaryLine: some View {
        HStack(spacing: 10) {
            Text("景品 \(store.state.collected.count)個")
            if store.totalCutIns > 0 {
                Text("割り込まれた \(store.totalCutIns)人")
            }
            if store.state.totalTaps > 0 {
                Text("叩いた \(store.state.totalTaps)回")
            }
        }
        .font(.caption2)
        .foregroundStyle(AppTheme.inkSecondary)
    }

    // MARK: - 動作

    private func tapPersonAhead() {
        let outcome = store.tapPersonAhead()
        show(reaction: outcome.message)

        UIImpactFeedbackGenerator(style: outcome.didAdvance ? .heavy : .light)
            .impactOccurred()

        if outcome.didAdvance {
            Task { await rescheduleNotifications() }
        }
    }

    /// 少しのあいだだけ反応を表示する。連続で叩かれても最後のものだけが残る。
    private func show(reaction message: String) {
        reaction = message
        reactionToken += 1
        let token = reactionToken

        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if token == reactionToken { reaction = nil }
        }
    }

    private func claim() {
        guard let record = store.claimPrize() else { return }
        claimedPrize = record
        isShowingPrize = true
        Task { await rescheduleNotifications() }
    }

    private func skipAhead() async {
        guard await purchases.purchaseSkip() else { return }
        store.skipAhead(by: PurchaseStore.skipAmount)
        await rescheduleNotifications()
    }

    private func leaveQueue() {
        store.leaveQueue()
        Task { await rescheduleNotifications() }
    }

    private func rescheduleNotifications() async {
        await NotificationScheduler.reschedule(
            anchorPosition: store.state.anchorPosition,
            anchorDate: store.state.anchorDate
        )
    }
}
