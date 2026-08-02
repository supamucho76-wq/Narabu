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
    /// 長押しで開く、5つの手の一覧。
    @State private var isShowingAllActions = false
    @State private var reaction: ActionOutcome?
    @State private var reactionToken = 0
    @State private var disturbance: Double = 0
    @State private var gachaMode: GachaView.Mode?
    @State private var clearResult: StageClearResult?
    @State private var activeMission: Mission?
    /// 前へ進んでいる最中の演出。終わるまで操作を受け付けない。
    @State private var surge: Surge?
    /// 連続成功の段が上がった瞬間だけ出す。
    @State private var tierUp: ComboTier?
    @State private var tierUpToken = 0
    /// ミッションに成功したあとの抽選。決まってから走り出す。
    @State private var lottery: Lottery?
    @State private var pendingSurge: PendingSurge?

    /// 抽選を待っている前進。上乗せが決まってから、まとめて演出する。
    private struct PendingSurge {
        /// 走り出す前の残り人数。
        let fromRemaining: Int
        /// 上乗せ前に進んだ人数。
        let base: Int
    }
    @State private var isShowingVoicePermission = false
    @AppStorage("hasSeenIntro") private var hasSeenIntro = false

    private var isBusy: Bool {
        surge != nil || activeMission != nil || store.pendingEvent != nil || lottery != nil
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

            tierUpBanner
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
                MissionView(mission: mission, reward: store.projectedReward(for: mission)) { success in
                    // 成功でも失敗でも、必ず同じ後始末を通してから画面を閉じる。
                    let before = store.remaining
                    store.completeMission(mission, success: success)
                    activeMission = nil
                    sound.play(success ? .clear : .fail)

                    // 実際に減った人数で演出する。倍率がかかっていても必ず一致する。
                    let skipped = before - store.remaining
                    if skipped > 0 {
                        startLottery(fromRemaining: before, base: skipped)
                    }
                }
                .transition(.opacity)
            }

            if let lottery, let pending = pendingSurge {
                LotteryView(
                    lottery: lottery,
                    basePeople: pending.base,
                    remainingBefore: pending.fromRemaining
                ) { result in
                    finishLottery(result, pending: pending)
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
        .sheet(isPresented: $isShowingAllActions) {
            allActionsSheet
                .presentationDetents([.height(260)])
        }
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
        .onChange(of: store.comboTier) { previous, current in
            // 上がったときだけ知らせる。切れて下がったときは静かに戻す。
            guard current > previous else {
                withAnimation(.easeOut(duration: 0.2)) { tierUp = nil }
                return
            }
            announce(current)
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
                menuButton
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

    /// 段が上がった瞬間に、画面の真ん中で知らせる。
    ///
    /// ここが積み上げの見返りなので、静かに数字が変わるだけにはしない。
    @ViewBuilder
    private var tierUpBanner: some View {
        if let tierUp, let label = tierUp.label {
            VStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 40, weight: .black, design: .rounded))
                if let multiplier = tierUp.multiplierLabel {
                    Text("\(multiplier) で進む")
                        .font(.system(size: 16, weight: .black))
                }
            }
            .foregroundStyle(tierUp.color)
            .shadow(color: .black.opacity(0.5), radius: 8)
            .padding(.horizontal, 26)
            .padding(.vertical, 14)
            .background(.black.opacity(0.42))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .transition(.scale(scale: 0.5).combined(with: .opacity))
            .allowsHitTesting(false)
        }
    }

    /// いま何倍で進めているか、次の段まであと何回か。
    ///
    /// 倍率が見えていないと、連続を積む理由が伝わらない。
    private var comboBadge: some View {
        let tier = store.comboTier

        return HStack(spacing: 5) {
            Image(systemName: tier.symbolName)
            Text("\(store.combo)連続")
            if let multiplier = tier.multiplierLabel {
                Text(multiplier)
                    .font(.system(size: 13, weight: .black))
            }
            if let label = tier.label {
                Text(label)
            }
            if let remaining = store.comboToNextTier, remaining <= 2 {
                Text("あと\(remaining)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .font(.system(size: 11, weight: .black))
        .foregroundStyle(tier == .none ? .white : tier.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(.black.opacity(0.45))
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
                            .foregroundStyle(reaction.advance > 0 ? AppTheme.stamp : AppTheme.inkSecondary)
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
                            .foregroundStyle(AppTheme.inkSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    // 連続を積むほどここの数が跳ね上がる。挑む理由になる。
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("+\(store.projectedReward(for: mission))人")
                            .font(.caption.weight(.black))
                            .contentTransition(.numericText())

                        if let label = ComboTier.of(store.combo + 1).multiplierLabel {
                            Text(label)
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(ComboTier.of(store.combo + 1).color)
                                .clipShape(Capsule())
                        }
                    }
                    .animation(.snappy, value: store.combo)
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

    /// いま前にいる人に対して、まず思いつく手。
    ///
    /// 5つ全部を常に並べると、初見でどれを押すゲームなのか分からなくなる。
    /// **画面には1つだけ出し、相手が変われば入れ替わる。**
    /// 他の手を選びたいときは、長押しで全部出す。
    private var situationalAction: QueueAction {
        switch store.personAhead.activity {
        // 気づいていない相手には、まず触れる。
        case .phone, .reading, .music: return .tapShoulder
        // 手がふさがっている相手には、声をかける。
        case .coffee, .shopping, .suitcase, .umbrella: return .talk
        // 動きの止まっている相手は、驚かせるのが手っ取り早い。
        case .sleeping, .standing: return .surprise
        // 体を動かしている相手には、ノリで合わせる。
        case .exercising, .stretching: return .highFive
        case .walkingDog: return .cheer
        }
    }

    /// 常時見えているのは、状況アクション・突破・アイテムの3つだけ。
    private var actionRow: some View {
        HStack(spacing: 8) {
            situationalActionButton
            itemButton
        }
    }

    private var situationalActionButton: some View {
        let action = situationalAction

        return Button {
            perform(action)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: action.symbolName)
                    .font(.system(size: 20, weight: .semibold))
                Text(action.label)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 62)
            .background(AppTheme.paper.opacity(0.96))
            .foregroundStyle(AppTheme.ink)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(GameButtonStyle())
        .disabled(store.hasClearedStage || isBusy)
        // 他の手も使いたい人のために、長押しで5つ全部を出す。
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.35).onEnded { _ in
                guard !isBusy, !store.hasClearedStage else { return }
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                isShowingAllActions = true
            }
        )
    }

    private var itemButton: some View {
        Button {
            isShowingItems = true
        } label: {
            VStack(spacing: 3) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 20, weight: .semibold))
                Text(itemCount > 0 ? "アイテム \(itemCount)" : "アイテム")
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 62)
            .background(itemCount > 0
                        ? Color(red: 0.98, green: 0.90, blue: 0.62)
                        : AppTheme.paper.opacity(0.96))
            .foregroundStyle(AppTheme.ink)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(GameButtonStyle())
        .disabled(isBusy)
    }

    private var itemCount: Int {
        store.ownedItems.reduce(0) { $0 + $1.count }
    }

    /// 長押しで開く、5つの手。普段は画面に出さない。
    private var allActionsSheet: some View {
        VStack(spacing: 12) {
            Text("どう出るか選ぶ")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)

            ForEach(QueueAction.allCases) { action in
                Button {
                    isShowingAllActions = false
                    perform(action)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: action.symbolName)
                            .font(.system(size: 16))
                            .frame(width: 26)
                        Text(action.label)
                            .font(.subheadline.weight(.bold))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: AppTheme.minimumTapHeight)
                    .background(AppTheme.ink.opacity(0.06))
                    .foregroundStyle(AppTheme.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(GameButtonStyle())
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.paper)
    }

    // MARK: - 6. その他

    @ViewBuilder
    private var bottomBar: some View {
        if store.hasClearedStage {
            Button("先頭に着いた！　クリア") { clearStage() }
                .buttonStyle(QuietButtonStyle(emphasized: true))
                .padding(.top, 10)
        }
    }

    /// 装備・図鑑は常時出さず、上のメニューにしまう。
    private var menuButton: some View {
        Menu {
            Button {
                isShowingLoadout = true
            } label: {
                Label("装備とスキル", systemImage: "person.crop.circle.badge.checkmark")
            }
            Button {
                isShowingCollection = true
            } label: {
                Label("図鑑", systemImage: "book.closed")
            }
        } label: {
            Image(systemName: "ellipsis.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .disabled(isBusy)
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
            // 連続しているぶんだけ音が上がっていく。押し続けたくなるのはこの音のおかげ。
            sound.playStep(store.combo)
        case .good:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            sound.playStep(store.combo)
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
        case .huge, .unreal:
            // 桁が変わったのが指でも分かるように、重い振動を畳みかける。
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            sound.play(.great)
            Task {
                for _ in 0..<3 {
                    try? await Task.sleep(for: .seconds(0.11))
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                }
            }
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

    // MARK: - 抽選

    /// ミッションの前進を、抽選が決まるまで預かる。
    ///
    /// 内部の人数はもう動いているが、画面はこの演出が終わってから追いつく。
    /// 途中でアプリを閉じても、稼いだぶんが消えることはない。
    private func startLottery(fromRemaining: Int, base: Int) {
        pendingSurge = PendingSurge(fromRemaining: fromRemaining, base: base)
        lottery = Lottery.draw(
            seed: Int(Date().timeIntervalSince1970 * 1_000) &+ base &* 31 &+ store.combo
        )
    }

    private func finishLottery(_ result: Lottery.Result, pending: PendingSurge) {
        lottery = nil
        pendingSurge = nil

        // 上乗せぶんをここで足す。
        let extra = pending.base * (result.multiplier - 1)
        if extra > 0 { store.skipAhead(by: extra) }

        // 列より多く抜いたぶんは消さずにコインへ回す。
        // 「102人抜いたのに34人しか減らない」を、損に見せないための受け皿。
        let claimed = pending.base * result.multiplier
        let overflow = max(0, claimed - pending.fromRemaining)
        if overflow > 0 {
            store.awardCoins(overflow * LotteryView.coinsPerOverflow)
        }

        let total = pending.fromRemaining - store.remaining
        if total > 0 {
            surgeForward(people: total, from: pending.fromRemaining)
        }
    }

    /// 段が上がったことを、音と振動と文字で一度に伝える。
    private func announce(_ tier: ComboTier) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { tierUp = tier }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        sound.play(.great)

        tierUpToken += 1
        let token = tierUpToken
        Task {
            try? await Task.sleep(for: .seconds(1.1))
            guard token == tierUpToken else { return }
            withAnimation(.easeOut(duration: 0.25)) { tierUp = nil }
        }
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
