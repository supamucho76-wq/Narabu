import SwiftUI
import UIKit

/// 並んでいるあいだ、ずっと表示されている画面。
///
/// 上から順に、残り人数 → ミッション → コンボ → 人物 → アクション、の優先度で置く。
struct QueueView: View {
    @Environment(QueueStore.self) private var store
    @Environment(PurchaseStore.self) private var purchases
    @Environment(SoundPlayer.self) private var sound
    @Environment(VoiceRecognizer.self) private var voice

    @State private var isShowingCollection = false
    @State private var isShowingItems = false
    @State private var isShowingLoadout = false
    @State private var reaction: ActionOutcome?
    @State private var reactionToken = 0
    @State private var disturbance: Double = 0
    @State private var gachaMode: GachaView.Mode?
    @State private var clearResult: StageClearResult?
    @State private var activeMission: Mission?
    /// 前へ進んでいる最中の演出。終わるまで操作を受け付けない。
    @State private var surge: Surge?
    @State private var isShowingVoicePermission = false
    @AppStorage("hasSeenIntro") private var hasSeenIntro = false

    private var isBusy: Bool {
        surge != nil || activeMission != nil || store.pendingEvent != nil
    }

    var body: some View {
        ZStack {
            // Canvasが何らかの理由で描けなくても、白い画面にはしない。
            store.scene.skyColors.bottom.ignoresSafeArea()

            world

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 0)
                reactionToast
                personCard
                missionCard
                voiceControl
                actionRow
                bottomBar
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
            .opacity(surge == nil ? 1 : 0.25)
            .allowsHitTesting(!isBusy)
            .animation(.easeInOut(duration: 0.2), value: isBusy)

            gainBannerView

            if let event = store.pendingEvent {
                EventView(event: event) { choice in
                    let before = store.remaining
                    store.resolveEvent(choice)
                    sound.play(choice.advance >= 0 ? .success : .fail)
                    if choice.advance > 0 {
                        surgeForward(people: choice.advance, from: before)
                    }
                }
                .transition(.opacity)
            } else if let mission = activeMission {
                MissionView(mission: mission) { success in
                    // 成功でも失敗でも、必ず同じ後始末を通してから画面を閉じる。
                    let before = store.remaining
                    store.completeMission(mission, success: success)
                    activeMission = nil
                    sound.play(success ? .clear : .fail)
                    if success {
                        surgeForward(people: mission.reward, from: before)
                    }
                }
                .transition(.opacity)
            }

            if !hasSeenIntro {
                IntroView { hasSeenIntro = true }
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: activeMission)
        .animation(.easeInOut(duration: 0.4), value: hasSeenIntro)
        .onChange(of: store.scene) { _, scene in
            show(.init(grade: .good, message: "\(scene.name)まで来た。", advance: 0))
            sound.play(mood: SceneMood.of(scene))
        }
        .onChange(of: hasSeenIntro) { _, seen in
            if seen, store.needsStarterGacha { gachaMode = .starter }
        }
        .sheet(isPresented: $isShowingCollection) { CollectionView() }
        .sheet(isPresented: $isShowingItems) {
            ItemSheet(
                onUse: { item in use(item) },
                onPurchase: { Task { await purchaseSkip() } }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isShowingLoadout) { LoadoutView() }
        .sheet(isPresented: $isShowingVoicePermission) {
            VoicePermissionView()
                .presentationDetents([.large])
        }
        .fullScreenCover(item: $gachaMode) { mode in
            GachaView(mode: mode, onDraw: { draw(mode) }, onFinish: { gachaMode = nil })
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
            store.ensureMission()
            sound.play(mood: SceneMood.of(store.scene))
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
            surge: surge,

            // 吹き出しは同時にひとつだけ。反応が出ているあいだは前の人が黙る。
            silencesRemark: reaction != nil || surge != nil,
            onTapPersonAhead: {}
        )
        .ignoresSafeArea()
    }

    // MARK: - 1. 残り人数

    private var topBar: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Text("STAGE \(store.state.stageNumber)")
                    .font(.system(size: 10, weight: .black))
                Text(store.stage.name)
                    .font(.caption2.weight(.bold))
                Spacer()
                gachaCorner
            }

            remainingLine

            progressBar

            HStack(spacing: 10) {
                labelledGauge(
                    title: "集中",
                    ratio: store.focusRatio,
                    tint: store.isFocusLow
                        ? Color(red: 0.94, green: 0.52, blue: 0.34)
                        : Color(red: 0.52, green: 0.82, blue: 0.92)
                )
                labelledGauge(
                    title: "警戒",
                    ratio: store.alertness / Alertness.maximum,
                    tint: store.alertLevel.color
                )
            }

            // ゲージが何を引き起こすかを、必要なときだけ言葉で出す。
            HStack(spacing: 8) {
                if let warning = gaugeWarning {
                    Text(warning.text)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(warning.color)
                }
                if store.combo >= 3 {
                    comboBadge
                }
            }
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.65), radius: 5, y: 1)
        .padding(.top, 0)
    }

    /// 残り人数。進んでいる最中は、演出に合わせて数字が減っていく。
    ///
    /// 内部の数はすでに減っているが、いきなり飛ぶと何が起きたか分からない。
    @ViewBuilder
    private var remainingLine: some View {
        if let surge {
            TimelineView(.animation) { timeline in
                remainingText(surge.displayedRemaining(at: timeline.date))
            }
        } else {
            remainingText(store.remaining)
        }
    }

    private func remainingText(_ value: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text("あと")
            Text(max(0, value), format: .number)
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
                .animation(.snappy, value: value)
            Text("人")
        }
        .font(.caption.weight(.medium))
    }

    /// ゲージが傾いているときだけ、何が起きるかを教える。
    private var gaugeWarning: (text: String, color: Color)? {
        if store.alertLevel == .dangerous {
            return ("警戒MAX　強引な手が通らず、警備員に戻される", store.alertLevel.color)
        }
        if store.alertLevel == .watched {
            return ("見られている　強引な手が通りにくい", store.alertLevel.color)
        }
        if store.isFocusLow {
            return ("集中切れ　成功しにくく、進みも1人減る", Color(red: 1.0, green: 0.72, blue: 0.56))
        }
        if store.focusRatio > 0.95, store.alertness < 10 {
            return ("絶好調　いまが押しどき", Color(red: 0.62, green: 0.88, blue: 0.72))
        }
        return nil
    }

    /// 何のゲージか分かるよう、必ず名前を添える。
    private func labelledGauge(title: String, ratio: Double, tint: Color) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.2))
                    Capsule()
                        .fill(tint)
                        .frame(width: max(2, geometry.size.width * min(1, max(0, ratio))))
                        .animation(.easeOut(duration: 0.3), value: ratio)
                }
            }
            .frame(height: 4)
        }
    }

    /// 残り人数が減るほど、バーはゴール側へ伸びる。
    private var progressBar: some View {
        GeometryReader { geometry in
            let ratio = Double(store.progress) / Double(max(1, store.stage.queueLength))
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.25))
                Capsule()
                    .fill(store.isFever ? Color(red: 1.0, green: 0.72, blue: 0.2) : AppTheme.stamp)
                    .frame(width: max(2, geometry.size.width * min(1, max(0, ratio))))
                    .animation(.easeOut(duration: 0.4), value: ratio)
            }
        }
        .frame(height: 4)
    }

    /// ガチャの残り時間は隅に小さく。引ける時だけ色がつく。
    @ViewBuilder
    private var gachaCorner: some View {
        if store.canDrawFreeGacha {
            Button { gachaMode = .free } label: {
                HStack(spacing: 4) {
                    Text("NEW")
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(AppTheme.stamp)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(.white)
                        .clipShape(Capsule())
                    Label("無料ガチャ", systemImage: "gift.fill")
                        .font(.system(size: 10, weight: .bold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(AppTheme.stamp)
                .clipShape(Capsule())
                .shadow(color: AppTheme.stamp.opacity(0.6), radius: 6)
            }
            .buttonStyle(GameButtonStyle())
        } else if store.canDrawWithTicket {
            Button { gachaMode = .ticket } label: {
                Label("チケット\(store.state.gachaTickets)", systemImage: "ticket.fill")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color(red: 0.30, green: 0.48, blue: 0.72))
                    .clipShape(Capsule())
            }
            .buttonStyle(GameButtonStyle())
        } else if let cooldown = store.freeGachaCooldown {
            Label(GachaMachine.countdownLabel(cooldown), systemImage: "clock")
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .opacity(0.75)
        }
    }

    /// 進んでいる最中、画面の真ん中で人数が増えていくのを見せる。
    ///
    /// 抜いた人数が多いほど大きく、強い段階では見出しも付く。
    @ViewBuilder
    private var gainBannerView: some View {
        if let surge {
            TimelineView(.animation) { timeline in
                let counted = surge.countedSoFar(at: timeline.date)
                let done = surge.isFinished(at: timeline.date)

                VStack(spacing: 2) {
                    if let headline = surge.tier.headline {
                        Text(headline)
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(Color(red: 1.0, green: 0.86, blue: 0.34))
                    }
                    Text("＋\(counted)人")
                        .font(.system(size: surge.tier.bannerSize, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    if let name = surge.vehicleName {
                        Text(name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .shadow(color: AppTheme.stamp.opacity(0.9), radius: 12)
                .shadow(color: .black.opacity(0.55), radius: 4, y: 2)
                .scaleEffect(done ? 1.08 : 1)
                .opacity(done ? 0 : 1)
                .animation(.easeOut(duration: 0.25), value: done)
            }
            .allowsHitTesting(false)
        }
    }

    // MARK: - 3. コンボ

    private var comboBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: store.isFever ? "flame.fill" : "bolt.fill")
            Text(store.isFever ? "フィーバー！ \(store.combo)連続" : "\(store.combo)連続")
        }
        .font(.system(size: 11, weight: .black))
        .foregroundStyle(store.isFever ? Color(red: 1.0, green: 0.78, blue: 0.24) : .white)
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(.black.opacity(0.35))
        .clipShape(Capsule())
        .transition(.scale.combined(with: .opacity))
        .animation(.snappy, value: store.combo)
    }

    // MARK: - 反応

    private var reactionToast: some View {
        Group {
            if let reaction {
                HStack(spacing: 8) {
                    if reaction.advance != 0 {
                        Text(reaction.advance > 0 ? "+\(reaction.advance)人" : "\(reaction.advance)人")
                            .font(.caption.weight(.black))
                            .foregroundStyle(reaction.advance > 0 ? AppTheme.stamp : .secondary)
                    }
                    Text(reaction.message)
                        .font(.caption)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(AppTheme.paper.opacity(0.96))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .foregroundStyle(AppTheme.ink)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: reaction)
        .padding(.bottom, 8)
    }

    // MARK: - 4. 人物

    /// 前の人の様子。ここを読めば、どのアクションが効くか分かる。
    private var personCard: some View {
        let person = store.personAhead

        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text("前の人")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(.secondary)
                Text(person.descriptor)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(person.personality.label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.stamp)
            }
            Text(person.personality.hint)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // 説明で終わらせず、どう攻めるかの材料にする。
            HStack(alignment: .top, spacing: 5) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(Color(red: 0.82, green: 0.62, blue: 0.16))
                    .padding(.top, 2)
                Text(person.personality.tactic)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.ink.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(AppTheme.paper.opacity(0.94))
        .foregroundStyle(AppTheme.ink)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.bottom, 6)
    }

    // MARK: - 2. ミッション

    @ViewBuilder
    private var missionCard: some View {
        if let mission = store.currentMission, !store.hasClearedStage {
            Button {
                activeMission = mission
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "target")
                        .font(.system(size: 14))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(mission.title)
                            .font(.caption.weight(.bold))
                        Text(mission.instruction)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text("+\(mission.reward)人")
                        .font(.caption.weight(.black))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: AppTheme.minimumTapHeight)
                .background(Color(red: 1.0, green: 0.88, blue: 0.52))
                .foregroundStyle(AppTheme.ink)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(GameButtonStyle())
            .disabled(isBusy)
            .padding(.bottom, 6)
        }
    }

    // MARK: - 3. 声で押し通す

    @ViewBuilder
    private var voiceControl: some View {
        if !store.hasClearedStage {
            VoiceControl(
                onVoice: { phrase, volume in breakThrough(phrase, volume) },
                onSilent: { phrase, volume in breakThrough(phrase, volume) },
                onNeedsPermission: { isShowingVoicePermission = true }
            )
            .padding(.bottom, 6)
        }
    }

    // MARK: - 5. アクション

    private var actionRow: some View {
        HStack(spacing: 5) {
            ForEach(QueueAction.allCases) { action in
                Button {
                    perform(action)
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: action.symbolName)
                            .font(.system(size: 13))
                        Text(action.label)
                            .font(.system(size: 8, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, minHeight: AppTheme.minimumTapHeight)
                    .background(AppTheme.paper.opacity(0.94))
                    .foregroundStyle(AppTheme.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(GameButtonStyle())
                .disabled(store.hasClearedStage || isBusy)
            }
        }
    }

    // MARK: - 6. その他

    private var bottomBar: some View {
        VStack(spacing: 6) {
            if store.hasClearedStage {
                Button("先頭に着いた！　クリア") { clearStage() }
                    .buttonStyle(QuietButtonStyle(emphasized: true))
            }

            HStack(spacing: 6) {
                Button {
                    isShowingItems = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "shippingbox.fill")
                        Text("アイテム")
                        if store.ownedItems.isEmpty == false {
                            countBadge(store.ownedItems.reduce(0) { $0 + $1.count })
                        }
                    }
                }
                .buttonStyle(QuietButtonStyle())

                Button { isShowingLoadout = true } label: {
                    Label("装備", systemImage: "person.crop.circle.badge.checkmark")
                }
                .buttonStyle(QuietButtonStyle())

                Button("図鑑") { isShowingCollection = true }
                    .buttonStyle(QuietButtonStyle())
            }
        }
        // アクションボタンとの誤タップを防ぐ余白。
        .padding(.top, 14)
    }

    private func countBadge(_ count: Int) -> some View {
        Text("\(count)")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(AppTheme.stamp)
            .clipShape(Capsule())
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

        let before = store.remaining
        let outcome = store.interactWithPersonAhead(action)
        show(outcome)

        switch outcome.grade {
        case .great:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            sound.play(.great)
        case .good:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            sound.play(.success)
        case .miss:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            sound.play(.tap)
        case .backfire:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            sound.play(.fail)
        }

        if outcome.advance > 0 {
            surgeForward(people: outcome.advance, from: before)
        }

        withAnimation(.easeOut(duration: 0.12)) { disturbance = 1 }
        withAnimation(.easeIn(duration: 0.45).delay(0.12)) { disturbance = 0 }
    }

    /// 前へ進んだことを見せる。すべての前進がここを通る。
    ///
    /// 数字は内部ではすでに減っているが、画面はこの演出に合わせて追いつく。
    /// 終わったら必ず状態を戻すので、途中で何が起きても取り残されない。
    private func surgeForward(people: Int, from before: Int, vehicle: GachaItem? = nil) {
        guard people > 0 else { return }

        let run = Surge(
            fromRemaining: before,
            peopleSkipped: people,
            startedAt: .now,
            vehicle: vehicle?.vehicle,
            vehicleName: vehicle?.name
        )
        surge = run

        switch run.tier {
        case .slight:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .moderate:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .strong:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            sound.play(.overtake)
        case .massive:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            sound.play(.overtake)
        }

        Task {
            try? await Task.sleep(for: .seconds(run.duration + 0.25))
            // 演出の残りをすべて片付けて、操作できる状態に戻す。
            surge = nil
            disturbance = 0
            await rescheduleNotifications()
        }
    }

    /// 声、またはタップの強さで押し通す。
    private func breakThrough(_ phrase: VoicePhrase, _ volume: VoiceVolume) {
        guard !isBusy else { return }

        let before = store.remaining
        let outcome = store.breakThrough(phrase: phrase, volume: volume)
        show(.init(
            grade: outcome.succeeded ? .great : (outcome.advance < 0 ? .backfire : .miss),
            message: outcome.message,
            advance: outcome.advance
        ))

        if outcome.caughtByGuard {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            sound.play(.fail)
        } else if outcome.succeeded {
            sound.play(.great)
            surgeForward(people: outcome.advance, from: before)
        } else {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            sound.play(.fail)
        }

        withAnimation(.easeOut(duration: 0.12)) { disturbance = 1 }
        withAnimation(.easeIn(duration: 0.5).delay(0.12)) { disturbance = 0 }
    }

    private func use(_ item: GachaItem) {
        guard !isBusy else { return }

        let before = store.remaining
        let skipped = store.useItem(item)
        guard skipped > 0 else { return }

        surgeForward(people: skipped, from: before, vehicle: item)
    }

    private func purchaseSkip() async {
        guard !isBusy, await purchases.purchaseSkip() else { return }

        let before = store.remaining
        let skipped = min(PurchaseStore.skipAmount, before)
        guard skipped > 0 else { return }

        store.skipAhead(by: skipped)
        surgeForward(people: skipped, from: before, vehicle: GachaCatalog.item(id: "car"))
    }

    private func clearStage() {
        guard let result = store.clearStage() else { return }
        clearResult = result
        store.ensureMission()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        sound.play(.clear)
        Task { await rescheduleNotifications() }
    }

    private func show(_ outcome: ActionOutcome) {
        reaction = outcome
        reactionToken += 1
        let token = reactionToken

        Task {
            try? await Task.sleep(for: .seconds(2.2))
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
