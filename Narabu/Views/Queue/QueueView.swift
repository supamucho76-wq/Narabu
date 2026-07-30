import SwiftUI
import UIKit

/// 並んでいるあいだ、ずっと表示されている画面。
/// 画面のほとんどは列そのもので、数字は控えめに重ねるだけ。
struct QueueView: View {
    @Environment(QueueStore.self) private var store
    @Environment(PurchaseStore.self) private var purchases

    @State private var isShowingCollection = false
    @State private var isShowingItems = false
    @State private var isShowingLoadout = false
    @State private var reaction: String?
    @State private var reactionToken = 0
    @State private var disturbance: Double = 0
    @State private var overtake: OvertakeRun?
    @State private var gachaMode: GachaView.Mode?
    @State private var clearResult: StageClearResult?
    @AppStorage("hasSeenIntro") private var hasSeenIntro = false

    /// 演出中はボタンを受け付けない。
    private var isBusy: Bool { overtake != nil }

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
            .opacity(isBusy ? 0.25 : 1)
            .allowsHitTesting(!isBusy)
            .animation(.easeInOut(duration: 0.2), value: isBusy)

            if !hasSeenIntro {
                IntroView { hasSeenIntro = true }
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: hasSeenIntro)
        .onChange(of: store.scene) { _, scene in
            show(reaction: "\(scene.name)まで来た。")
        }
        .onChange(of: hasSeenIntro) { _, seen in
            if seen, store.needsStarterGacha { gachaMode = .starter }
        }
        .sheet(isPresented: $isShowingCollection) {
            CollectionView()
        }
        .sheet(isPresented: $isShowingItems) {
            ItemSheet(
                onUse: { item in use(item) },
                onPurchase: { Task { await purchaseSkip() } }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isShowingLoadout) {
            LoadoutView()
        }
        .fullScreenCover(item: $gachaMode) { mode in
            GachaView(
                mode: mode,
                onDraw: { draw(mode) },
                onFinish: { gachaMode = nil }
            )
        }
        .fullScreenCover(item: $clearResult) { result in
            StageClearView(
                result: result,
                nextStage: store.stage,
                onContinue: { clearResult = nil }
            )
        }
        .task {
            store.startTicking()
            await NotificationScheduler.requestAuthorization()
            await rescheduleNotifications()
            if hasSeenIntro, store.needsStarterGacha { gachaMode = .starter }
        }
    }

    // MARK: - 列の世界

    private var world: some View {
        QueueWorldView(
            stage: store.stage,
            anchorProgress: store.state.anchorProgress,
            anchorDate: store.state.anchorDate,
            disturbance: disturbance,
            overtake: overtake,
            onTapPersonAhead: { if !isBusy { perform(.tapShoulder) } }
        )
        .ignoresSafeArea()
    }

    // MARK: - 上部

    private var topBar: some View {
        VStack(spacing: 5) {
            HStack(spacing: 8) {
                Text("STAGE \(store.state.stageNumber)")
                    .font(.system(size: 10, weight: .black))
                    .tracking(1)
                Text(store.stage.name)
                    .font(.caption2.weight(.bold))
                Spacer()
                if store.state.lap > 1 {
                    Text("\(store.state.lap)周目")
                }
                Text(store.scene.name)
            }
            .font(.caption2.weight(.semibold))

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("あと")
                Text(store.remaining, format: .number)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
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
            let ratio = Double(store.progress) / Double(max(1, store.stage.queueLength))
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
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(AppTheme.paper.opacity(0.92))
                    .foregroundStyle(AppTheme.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .disabled(store.hasClearedStage)
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - 下部

    private var bottomBar: some View {
        VStack(spacing: 6) {
            if store.hasClearedStage {
                Button("先頭に着いた！　クリア") { clearStage() }
                    .buttonStyle(QuietButtonStyle(emphasized: true))
            } else {
                gachaButton
            }

            HStack(spacing: 6) {
                Button {
                    isShowingItems = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "shippingbox.fill")
                        Text("アイテム")
                        if store.ownedItems.isEmpty == false {
                            countBadge(store.ownedItems.reduce(0) { $0 + $1.count })
                        }
                    }
                }
                .buttonStyle(QuietButtonStyle())

                Button {
                    isShowingLoadout = true
                } label: {
                    Label("装備", systemImage: "person.crop.circle.badge.checkmark")
                }
                .buttonStyle(QuietButtonStyle())

                Button("図鑑") { isShowingCollection = true }
                    .buttonStyle(QuietButtonStyle())
            }
        }
    }

    private func countBadge(_ count: Int) -> some View {
        Text("\(count)")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(AppTheme.stamp)
            .clipShape(Capsule())
    }

    /// 引ける時だけ目立たせ、それ以外は残り時間を静かに出す。
    @ViewBuilder
    private var gachaButton: some View {
        if store.canDrawFreeGacha {
            Button { gachaMode = .free } label: {
                Label("無料ガチャが引けます！", systemImage: "gift.fill")
            }
            .buttonStyle(QuietButtonStyle(emphasized: true))
        } else if store.canDrawWithTicket {
            Button { gachaMode = .ticket } label: {
                Label("チケットで引く（\(store.state.gachaTickets)枚）", systemImage: "ticket.fill")
            }
            .buttonStyle(QuietButtonStyle(emphasized: true))
        } else if let cooldown = store.freeGachaCooldown {
            HStack(spacing: 6) {
                Image(systemName: "clock")
                Text("次の無料ガチャまで \(GachaMachine.countdownLabel(cooldown))")
                    .monospacedDigit()
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(.black.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }

    // MARK: - 動作

    private func draw(_ mode: GachaView.Mode) -> [GachaItem] {
        switch mode {
        case .starter: store.drawStarterGacha()
        case .free: store.drawFreeGacha().map { [$0] } ?? []
        case .ticket: store.drawWithTicket().map { [$0] } ?? []
        }
    }

    private func perform(_ action: QueueAction) {
        guard !isBusy else { return }

        let outcome = store.interactWithPersonAhead(action)
        show(reaction: outcome.message)

        UIImpactFeedbackGenerator(style: outcome.didAdvance ? .heavy : .light)
            .impactOccurred()

        withAnimation(.easeOut(duration: 0.12)) { disturbance = 1 }
        withAnimation(.easeIn(duration: 0.45).delay(0.12)) { disturbance = 0 }

        if outcome.didAdvance {
            Task { await rescheduleNotifications() }
        }
    }

    /// アイテムを使ってごぼう抜きする。
    ///
    /// 順位は先に確定させ、画面だけが演出の時間をかけて追いつく。
    /// こうしておくと、途中でアプリを閉じてもアイテムが消えたままにならない。
    private func use(_ item: GachaItem) {
        guard !isBusy else { return }

        let before = store.remaining
        let skipped = store.useItem(item)
        guard skipped > 0 else { return }

        runOvertake(item: item, from: before, skipped: skipped)
    }

    /// 課金して進む。演出は車と同じものを使う。
    private func purchaseSkip() async {
        guard !isBusy, await purchases.purchaseSkip() else { return }

        let before = store.remaining
        let skipped = min(PurchaseStore.skipAmount, before)
        guard skipped > 0 else { return }

        store.skipAhead(by: skipped)
        if let car = GachaCatalog.item(id: "car") {
            runOvertake(item: car, from: before, skipped: skipped)
        }
    }

    private func runOvertake(item: GachaItem, from before: Int, skipped: Int) {
        let run = OvertakeRun(
            item: item,
            fromRemaining: before,
            peopleSkipped: skipped,
            startedAt: .now
        )
        overtake = run

        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        Task {
            try? await Task.sleep(for: .seconds(run.duration + 0.6))
            overtake = nil
            await rescheduleNotifications()
        }
    }

    private func clearStage() {
        guard let result = store.clearStage() else { return }
        clearResult = result
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        Task { await rescheduleNotifications() }
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

    private func rescheduleNotifications() async {
        await NotificationScheduler.reschedule(
            anchorProgress: store.state.anchorProgress,
            anchorDate: store.state.anchorDate,
            queueLength: store.stage.queueLength,
            stageName: store.stage.name
        )
    }
}

extension GachaView.Mode: Identifiable {
    var id: String {
        switch self {
        case .starter: "starter"
        case .free: "free"
        case .ticket: "ticket"
        }
    }
}

extension StageClearResult: Identifiable {
    var id: String { "\(stage.id)-\(souvenir.id)" }
}
