import SwiftUI
import UIKit

/// 並んでいるあいだ、ずっと表示されている画面。
/// 画面のほとんどは列そのもので、数字は控えめに重ねるだけ。
struct QueueView: View {
    @Environment(QueueStore.self) private var store
    @Environment(PurchaseStore.self) private var purchases

    @State private var isShowingCollection = false
    @State private var isShowingPrize = false
    @State private var claimedPrize: CollectedPrize?
    @State private var reaction: String?
    @State private var reactionToken = 0
    @State private var disturbance: Double = 0
    @AppStorage("hasSeenIntro") private var hasSeenIntro = false

    var body: some View {
        ZStack {
            world

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 0)
                reactionToast
                personAheadCaption
                actionRow
                bottomBar
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

            if !hasSeenIntro {
                IntroView { hasSeenIntro = true }
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: hasSeenIntro)
        .onChange(of: store.stage.name) { _, _ in
            // 新しい場所に着いたことを知らせる。
            show(reaction: store.stage.arrivalNote)
        }
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

    // MARK: - 列の世界

    private var world: some View {
        QueueWorldView(
            anchorProgress: store.state.anchorProgress,
            anchorDate: store.state.anchorDate,
            disturbance: disturbance,
            onTapPersonAhead: { perform(.tapShoulder) }
        )
        .ignoresSafeArea()
    }

    // MARK: - 上部

    private var topBar: some View {
        VStack(spacing: 5) {
            HStack(spacing: 10) {
                Text(QueueWorld.destination)
                    .font(.caption2.weight(.bold))
                Spacer()
                Text(store.stage.name)
                Text("\(store.state.lap)周目")
            }
            .font(.caption2.weight(.semibold))

            if let untilNext = store.peopleUntilNextStage, let next = store.nextStageName {
                Text("あと\(untilNext.formatted())人で\(next)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color(red: 1.0, green: 0.88, blue: 0.5))
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("あと")
                Text(store.remaining, format: .number)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.snappy, value: store.remaining)
                Text("人")
            }
            .font(.caption.weight(.medium))

            progressBar
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.6), radius: 5, y: 1)
        .padding(.top, 4)
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            let ratio = Double(store.progress) / Double(QueueWorld.length)
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.28))
                Capsule()
                    .fill(AppTheme.stamp)
                    .frame(width: max(2, geometry.size.width * ratio))
            }
        }
        .frame(height: 3)
        .padding(.horizontal, 2)
    }

    // MARK: - 反応と前の人

    private var reactionToast: some View {
        Group {
            if let reaction {
                Text(reaction)
                    .font(.footnote.weight(.medium))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AppTheme.paper.opacity(0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .foregroundStyle(AppTheme.ink)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: reaction)
        .padding(.bottom, 10)
    }

    private var personAheadCaption: some View {
        Text("前の人：\(store.personAhead.descriptor)")
            .font(.caption2.weight(.medium))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.6), radius: 4, y: 1)
            .padding(.bottom, 8)
    }

    // MARK: - アクション

    private var actionRow: some View {
        HStack(spacing: 6) {
            ForEach(QueueAction.allCases) { action in
                Button {
                    perform(action)
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: action.symbolName)
                            .font(.system(size: 15))
                        Text(action.label)
                            .font(.system(size: 9, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(AppTheme.paper.opacity(0.92))
                    .foregroundStyle(AppTheme.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .disabled(store.hasReachedReception)
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - 下部

    private var bottomBar: some View {
        VStack(spacing: 6) {
            if store.hasReachedReception {
                Button("受付で受け取る") { claim() }
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

            HStack(spacing: 6) {
                Button("景品図鑑") { isShowingCollection = true }
                    .buttonStyle(QuietButtonStyle())
                Button("列を抜ける") { store.leaveQueue() }
                    .buttonStyle(QuietButtonStyle())
            }
        }
    }

    // MARK: - 動作

    private func perform(_ action: QueueAction) {
        let outcome = store.interactWithPersonAhead(action)
        show(reaction: outcome.message)

        UIImpactFeedbackGenerator(style: outcome.didAdvance ? .heavy : .light)
            .impactOccurred()

        // 絡まれた前の人が一瞬だけ身をよじる。
        withAnimation(.easeOut(duration: 0.12)) { disturbance = 1 }
        withAnimation(.easeIn(duration: 0.45).delay(0.12)) { disturbance = 0 }

        if outcome.didAdvance {
            Task { await rescheduleNotifications() }
        }
    }

    /// 少しのあいだだけ反応を表示する。連続で押されても最後のものだけが残る。
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

    private func rescheduleNotifications() async {
        await NotificationScheduler.reschedule(
            anchorProgress: store.state.anchorProgress,
            anchorDate: store.state.anchorDate
        )
    }
}
