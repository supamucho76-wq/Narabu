import SwiftUI

/// 並んでいるあいだ、ずっと表示されている画面。
struct QueueView: View {
    @Environment(QueueStore.self) private var store
    @Environment(PurchaseStore.self) private var purchases

    @State private var isShowingCollection = false
    @State private var isShowingPrize = false
    @State private var claimedPrize: CollectedPrize?

    var body: some View {
        ZStack {
            AppTheme.sky(tone: store.scenery.skyTone)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 1.2), value: store.scenery.skyTone)

            VStack(spacing: 0) {
                conditionsBar
                Spacer(minLength: 0)
                positionDisplay
                Spacer(minLength: 0)
                sceneryPanel
                neighborsPanel
                actions
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
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

    // MARK: - 上部：天気と経過

    private var conditionsBar: some View {
        HStack(spacing: 16) {
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
        .padding(.top, 8)
    }

    // MARK: - 中央：並び順

    private var positionDisplay: some View {
        VStack(spacing: 4) {
            if store.hasReachedFront {
                PlacardLabel(text: "お呼びしました")
                Text("先頭")
                    .font(.system(size: 76, weight: .light, design: .serif))
                    .padding(.vertical, 8)
            } else {
                PlacardLabel(text: "あなたは")
                Text(store.position, format: .number)
                    .font(.system(size: 88, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.snappy, value: store.position)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                PlacardLabel(text: "人目です")
            }
        }
    }

    // MARK: - 景色

    private var sceneryPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(store.scenery.title)
                    .font(.footnote.weight(.semibold))
                Spacer()
                if let remaining = store.peopleUntilNextScenery, remaining > 0 {
                    Text("あと\(remaining.formatted())人で景色が変わります")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.inkSecondary)
                }
            }
            Text(store.scenery.description)
                .font(.footnote)
                .foregroundStyle(AppTheme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.paper.opacity(0.5))
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(AppTheme.ink.opacity(0.15), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .animation(.easeInOut(duration: 0.8), value: store.scenery.title)
    }

    // MARK: - 前後の人

    private var neighborsPanel: some View {
        VStack(spacing: 10) {
            if !store.hasReachedFront {
                NeighborRow(role: "前の人", neighbor: store.personAhead)
            }
            NeighborRow(role: "後ろの人", neighbor: store.personBehind)
        }
        .padding(.vertical, 16)
    }

    // MARK: - 操作

    private var actions: some View {
        VStack(spacing: 10) {
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

            HStack(spacing: 10) {
                Button("景品図鑑") { isShowingCollection = true }
                    .buttonStyle(QuietButtonStyle())

                Button("列を抜ける") { leaveQueue() }
                    .buttonStyle(QuietButtonStyle())
            }

            summaryLine
        }
    }

    private var summaryLine: some View {
        HStack(spacing: 12) {
            Text("景品 \(store.state.collected.count)個")
            if store.totalCutIns > 0 {
                Text("割り込まれた \(store.totalCutIns)人")
            }
            if store.state.totalSkipped > 0 {
                Text("抜かした \(store.state.totalSkipped)人")
            }
        }
        .font(.caption2)
        .foregroundStyle(AppTheme.inkSecondary)
        .padding(.top, 2)
    }

    // MARK: - 動作

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

private struct NeighborRow: View {
    let role: String
    let neighbor: Neighbor

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(role)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.inkSecondary)
                .frame(width: 48, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(neighbor.appearance)
                    .font(.footnote)
                Text("\(neighbor.behavior)。\(neighbor.waitingLabel)。")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}
