import XCTest
@testable import Narabu

/// 排出率の検証を毎回同じ結果にするための乱数。
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

/// QueueStore は画面と同じ場所で動くので、試験もそこに合わせる。
@MainActor
final class QueueEngineTests: XCTestCase {
    private let noon = Date(timeIntervalSince1970: 1_760_000_000)

    // MARK: - 列の進みかた

    func testSameIntervalAlwaysProducesSameResult() {
        let later = noon.addingTimeInterval(3_600 * 5)
        XCTAssertEqual(
            QueueEngine.servedCount(from: noon, to: later),
            QueueEngine.servedCount(from: noon, to: later),
            "同じ区間を何度計算しても結果が変わってはいけない"
        )
    }

    func testQueueAdvancesAsTimePasses() {
        let oneHour = QueueEngine.servedCount(from: noon, to: noon.addingTimeInterval(3_600))
        let twoHours = QueueEngine.servedCount(from: noon, to: noon.addingTimeInterval(7_200))
        XCTAssertGreaterThan(oneHour, 0)
        XCTAssertGreaterThan(twoHours, oneHour)
    }

    func testQueueNeverMovesBackwardForPastDates() {
        XCTAssertEqual(QueueEngine.servedCount(from: noon, to: noon.addingTimeInterval(-3_600)), 0)
        XCTAssertEqual(QueueEngine.cutInCount(from: noon, to: noon.addingTimeInterval(-3_600)), 0)
    }

    func testCutInCountNeverDecreases() {
        var previous = 0
        for hours in stride(from: 0, through: 48, by: 3) {
            let count = QueueEngine.cutInCount(
                from: noon,
                to: noon.addingTimeInterval(Double(hours) * 3_600)
            )
            XCTAssertGreaterThanOrEqual(count, previous, "\(hours)時間後に割り込み数が減っている")
            previous = count
        }
    }

    /// 自動前進はあくまで補助。速すぎると、遊ぶ前にステージが終わってしまう。
    func testPassiveAdvanceIsOnlyATrickle() {
        let perHour = QueueEngine.servedCountExact(from: noon, to: noon.addingTimeInterval(3_600))
        let secondsPerPerson = 3_600 / perHour
        XCTAssertGreaterThan(secondsPerPerson, 40, "自動で進みすぎて操作する意味がなくなる")
        XCTAssertLessThan(secondsPerPerson, 240, "遅すぎると止まって見える")
    }

    /// どれだけ放置しても、自動前進だけではステージが終わらないこと。
    ///
    /// ここが崩れると、久しぶりに開いた人がいきなりクリア画面を見ることになる。
    func testStagesNeverClearThemselvesWhileAway() {
        let store = QueueStore(fileURL: temporaryStateFile())

        for away in [5.0, 60.0, 60 * 24.0, 60 * 24 * 30.0] {
            store.overrideForTesting(anchorProgress: 0, anchorDate: noon, now: noon.addingTimeInterval(away * 60))

            XCTAssertGreaterThan(store.remaining, 0,
                                 "\(Int(away))分離れただけでステージが終わっている")
            XCTAssertFalse(store.hasClearedStage)
            XCTAssertNil(store.clearStage(), "操作していないのにクリアが成立している")
        }
    }

    /// 離れていた時間が長くても、進みは半分までに抑えること。
    func testOfflineProgressIsCapped() {
        let store = QueueStore(fileURL: temporaryStateFile())
        let length = store.stage.queueLength

        store.overrideForTesting(anchorProgress: 0, anchorDate: noon, now: noon.addingTimeInterval(86_400))
        XCTAssertLessThanOrEqual(store.progress, length / 2 + 1, "放置だけで進みすぎている")
    }

    /// 操作で先頭まで到達したときは、ちゃんとクリアできること。
    func testReachingTheFrontByPlayingStillClears() {
        let store = QueueStore(fileURL: temporaryStateFile())
        let length = store.stage.queueLength

        store.overrideForTesting(anchorProgress: length, anchorDate: noon, now: noon)
        XCTAssertEqual(store.remaining, 0)
        XCTAssertTrue(store.hasClearedStage)
        XCTAssertNotNil(store.clearStage())
    }

    func testRemainingNeverGoesNegative() {
        let store = QueueStore(fileURL: temporaryStateFile())

        for progress in [-50, 0, 5, 9_999] {
            store.overrideForTesting(anchorProgress: progress, anchorDate: noon, now: noon.addingTimeInterval(9_999))
            XCTAssertGreaterThanOrEqual(store.remaining, 0)
            XCTAssertGreaterThanOrEqual(store.progress, 0)
        }
    }

    private func temporaryStateFile() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("narabu-test-\(UUID().uuidString).json")
    }

    func testProgressStopsAtTheFrontOfTheStage() {
        let progress = QueueEngine.progress(
            anchorProgress: 0,
            anchorDate: noon,
            at: noon.addingTimeInterval(86_400),
            limit: 30
        )
        XCTAssertEqual(progress, 30)
    }

    // MARK: - ステージ

    func testStagesGetLongerAsYouGo() {
        var previous = 0
        for stage in StageCatalog.stages {
            XCTAssertGreaterThan(stage.queueLength, previous, "\(stage.name)が前より短い")
            previous = stage.queueLength
        }
    }

    func testStagesMatchTheSpecifiedSizes() {
        let sizes = StageCatalog.stages.map(\.queueLength)
        XCTAssertEqual(sizes, [10, 30, 80, 150, 300, 500, 1_000])
    }

    // MARK: - アクション

    /// 相手に合った手を選べば進み、間違えれば下がる。当てずっぽうでは進めない。
    func testActionResultDependsOnThePersonAhead() {
        let sleepy = PersonFactory.person(atQueueIndex: 7, scene: .shopping)
        let personality = sleepy.personality

        let best = QueueActions.outcome(
            action: personality.best,
            person: sleepy,
            repeatCount: 0,
            seed: 1
        )
        XCTAssertGreaterThan(best.advance, 0, "最適な手なのに進めない")

        let worst = QueueActions.outcome(
            action: personality.worst,
            person: sleepy,
            repeatCount: 0,
            seed: 1
        )
        XCTAssertLessThan(worst.advance, 0, "やってはいけない手なのに罰がない")
    }

    /// 同じボタンを連打するだけで最適解にならないこと。
    func testRepeatingTheSameActionStopsWorking() {
        let person = PersonFactory.person(atQueueIndex: 12, scene: .forest)
        let action = person.personality.best

        let fresh = (0..<200).filter { seed in
            QueueActions.outcome(action: action, person: person, repeatCount: 0, seed: seed).advance > 0
        }.count
        let tired = (0..<200).filter { seed in
            QueueActions.outcome(action: action, person: person, repeatCount: 4, seed: seed).advance > 0
        }.count

        XCTAssertGreaterThan(fresh, tired, "連打しても成功率が落ちていない")
    }

    func testEveryPersonalityHasADistinctBestAndWorstAction() {
        for personality in Personality.allCases {
            XCTAssertNotEqual(personality.best, personality.worst,
                              "\(personality.label)の最適解と地雷が同じ")
            XCTAssertFalse(personality.hint.isEmpty, "\(personality.label)に手がかりがない")
        }
    }

    /// 人物情報は説明で終わらせず、攻め方の材料になっていること。
    func testEveryPersonalityTellsHowToApproachThem() {
        for personality in Personality.allCases {
            XCTAssertFalse(personality.tactic.isEmpty, "\(personality.label)に攻め方の手がかりがない")
            XCTAssertNotEqual(personality.tactic, personality.hint,
                              "\(personality.label)の手がかりと攻め方が同じ文になっている")
            // 「肩を叩く」のような答えそのものは書かない。
            for action in QueueAction.allCases {
                XCTAssertFalse(personality.tactic.contains(action.label),
                               "\(personality.label)の攻め方に答えがそのまま書かれている")
            }
        }
    }

    // MARK: - ミッション

    /// アイテムが尽きても遊べるよう、ミッションは必ず作れること。
    func testMissionsAreAlwaysAvailableAndRewarding() {
        for seed in 0..<200 {
            let mission = MissionFactory.make(seed: seed, stage: StageCatalog.stages[0])
            XCTAssertGreaterThan(mission.reward, 0, "達成しても進めないミッションがある")
            XCTAssertGreaterThan(mission.coins, 0)
            XCTAssertFalse(mission.instruction.isEmpty)
        }
    }

    /// 残しているのは、操作と結果が直に結びつくものだけ。
    func testOnlyDirectMissionsRemain() {
        var seenTiming = false
        var seenMash = false

        for seed in 0..<300 {
            switch MissionFactory.make(seed: seed, stage: StageCatalog.stages[3]).kind {
            case .timing: seenTiming = true
            case .mash: seenMash = true
            }
        }

        XCTAssertTrue(seenTiming, "タイミングが出てこない")
        XCTAssertTrue(seenMash, "連打が出てこない")
    }

    /// タイミングは進むほど難しくなるが、狙えない幅にはしない。
    func testTimingStaysPlayableOnLaterStages() {
        for stage in StageCatalog.stages {
            for seed in 0..<200 {
                if case .timing(let width, let speed) = MissionFactory.make(seed: seed, stage: stage).kind {
                    XCTAssertGreaterThanOrEqual(width, 0.10, "\(stage.name)の当たり範囲が狭すぎる")
                    XCTAssertLessThanOrEqual(speed, 2.0, "\(stage.name)の針が速すぎる")
                }
            }
        }
    }

    func testEveryStageHasAtLeastOneScene() {
        for stage in StageCatalog.stages {
            XCTAssertFalse(stage.scenes.isEmpty, "\(stage.name)に景色がない")
        }
    }

    /// 最終ステージだけは、いくつもの景色を通り抜ける。
    func testFinalStageTravelsThroughManyScenes() {
        let final = StageCatalog.stages[StageCatalog.count - 1]
        XCTAssertGreaterThan(final.scenes.count, 3)
        XCTAssertEqual(final.scene(atProgress: 0), final.scenes[0])
        XCTAssertEqual(final.scene(atProgress: final.queueLength - 1), .ramen)
    }

    func testLoopingMakesStagesLonger() {
        let first = StageCatalog.stage(number: 1, lap: 1)
        let second = StageCatalog.stage(number: 1, lap: 2)
        XCTAssertGreaterThan(second.queueLength, first.queueLength)
        XCTAssertEqual(second.name, first.name)
    }

    // MARK: - 装備とスキル

    func testEffectsCombineMultiplicativelyAndAdditively() {
        let combined = LoadoutEffects.combine([
            LoadoutEffects(overtakeMultiplier: 1.5, eventSuccessBonus: 0.04),
            LoadoutEffects(overtakeMultiplier: 2.0, eventSuccessBonus: 0.02)
        ])
        XCTAssertEqual(combined.overtakeMultiplier, 3.0, accuracy: 0.001)
        XCTAssertEqual(combined.eventSuccessBonus, 0.06, accuracy: 0.001)
    }

    func testEffectsAreClampedSoTheyCannotBreakTheGame() {
        let extreme = LoadoutEffects(
            overtakeMultiplier: 999,
            gachaCooldownMultiplier: 0.0001,
            eventSuccessBonus: 5,
            gachaLuckBonus: 9
        ).clamped

        XCTAssertLessThanOrEqual(extreme.overtakeMultiplier, 8)
        XCTAssertGreaterThanOrEqual(extreme.gachaCooldownMultiplier, 0.2)
        XCTAssertLessThanOrEqual(extreme.eventSuccessBonus, 0.35)
        XCTAssertLessThanOrEqual(extreme.gachaLuckBonus, 1.0)
    }

    func testSkillGetsStrongerWithEachLevel() {
        let pressure = SkillCatalog.skill(id: "pressure")!
        let low = pressure.effects(atLevel: 1).overtakeMultiplier
        let high = pressure.effects(atLevel: 5).overtakeMultiplier
        XCTAssertGreaterThan(high, low)
    }

    func testUpgradeCostRisesWithLevel() {
        XCTAssertLessThan(Skill.upgradeCost(currentLevel: 1), Skill.upgradeCost(currentLevel: 4))
    }

    /// 報酬で配る装備とスキルが、実在するものを指しているか。
    func testStageRewardsReferToRealEquipmentAndSkills() {
        for stage in StageCatalog.stages {
            if let id = stage.reward.equipmentID {
                XCTAssertNotNil(EquipmentCatalog.equipment(id: id), "\(stage.name)の装備が存在しない")
            }
            if let id = stage.reward.skillID {
                XCTAssertNotNil(SkillCatalog.skill(id: id), "\(stage.name)のスキルが存在しない")
            }
        }
    }

    // MARK: - 集中力

    /// 減っても操作は止めない。成功しにくくなるだけ。
    func testFocusNeverBlocksPlay() {
        XCTAssertEqual(FocusGauge.successPenalty(FocusGauge.maximum), 0)
        XCTAssertGreaterThan(FocusGauge.successPenalty(0), 0)
        XCTAssertLessThan(FocusGauge.successPenalty(0), 0.4, "切れても勝てなくなるほど下げない")
    }

    /// 待たせる仕組みにしないため、短時間で戻ること。
    func testFocusRefillsWithinAMinute() {
        let refilled = FocusGauge.current(anchor: 0, anchorDate: noon, now: noon.addingTimeInterval(60))
        XCTAssertEqual(refilled, FocusGauge.maximum, accuracy: 0.001)
    }

    func testFocusStaysWithinBounds() {
        for seconds in stride(from: 0.0, through: 300, by: 11) {
            let value = FocusGauge.current(anchor: 30, anchorDate: noon, now: noon.addingTimeInterval(seconds))
            XCTAssertGreaterThanOrEqual(value, 0)
            XCTAssertLessThanOrEqual(value, FocusGauge.maximum)
        }
    }

    func testEveryActionCostsSomeFocus() {
        for action in QueueAction.allCases {
            XCTAssertGreaterThanOrEqual(FocusGauge.cost(for: action), 5)
            XCTAssertLessThanOrEqual(FocusGauge.cost(for: action), 15)
        }
    }

    // MARK: - 出来事

    func testEventsAlwaysOfferAChoiceThatMatters() {
        for seed in 0..<200 {
            let event = QueueEventFactory.make(seed: seed, stage: StageCatalog.stages[4])
            XCTAssertGreaterThanOrEqual(event.choices.count, 2, "選択肢が足りない")
            XCTAssertFalse(event.situation.isEmpty)

            // どの出来事にも、何かしら得のある選択肢が要る。
            let hasUpside = event.choices.contains { $0.advance > 0 || $0.coins > 0 || $0.itemID != nil }
            XCTAssertTrue(hasUpside, "\(event.title)に得のある選択肢がない")
        }
    }

    func testEventItemsExist() {
        for seed in 0..<200 {
            let event = QueueEventFactory.make(seed: seed, stage: StageCatalog.stages[0])
            for choice in event.choices {
                if let id = choice.itemID {
                    XCTAssertNotNil(GachaCatalog.item(id: id), "\(event.title)が存在しないアイテムを配ろうとしている")
                }
            }
        }
    }

    // MARK: - 装備と記念品

    func testEveryEquipmentTellsWhereItComesFrom() {
        for equipment in EquipmentCatalog.all {
            XCTAssertFalse(equipment.source.isEmpty, "\(equipment.name)の入手先が空")
            XCTAssertFalse(equipment.detail.isEmpty)
        }
    }

    func testSkillValueLabelsChangeWithLevel() {
        for skill in SkillCatalog.all {
            XCTAssertNotEqual(
                skill.valueLabel(atLevel: 1),
                skill.valueLabel(atLevel: 3),
                "\(skill.name)の効果が段階で変わって見えない"
            )
        }
    }

    /// 隠し効果は、集めた記念品のぶんだけ効くこと。
    func testHiddenPrizeEffectsAccumulate() {
        let withEffects = PrizeCatalog.all.filter { $0.hiddenEffect != nil }
        XCTAssertFalse(withEffects.isEmpty, "隠し効果を持つ記念品がひとつもない")

        let none = PrizeCatalog.hiddenEffects(ownedIDs: [])
        XCTAssertEqual(none.overtakeMultiplier, 1, accuracy: 0.001)

        let all = PrizeCatalog.hiddenEffects(ownedIDs: Set(withEffects.map(\.id)))
        XCTAssertGreaterThan(all.overtakeMultiplier, 1)
        XCTAssertNotNil(withEffects.first?.hiddenEffectLabel)
    }

    // MARK: - ボイス突破

    func testPhraseMatchingPrefersTheLongerWording() {
        XCTAssertEqual(VoicePhrase.match(in: "前に行かせてください"), .maeni)
        XCTAssertEqual(VoicePhrase.match(in: "すみません、通してください"), .tooshite)
        XCTAssertEqual(VoicePhrase.match(in: "どけ"), .doke)
        XCTAssertEqual(VoicePhrase.match(in: "おい"), .oi)
    }

    /// 周りの音を拾っただけで勝手に発動しないこと。
    func testUnrelatedSpeechDoesNotTriggerAnything() {
        XCTAssertNil(VoicePhrase.match(in: ""))
        XCTAssertNil(VoicePhrase.match(in: "今日はいい天気ですね"))
        XCTAssertNil(VoicePhrase.match(in: "ラーメン食べたい"))
    }

    func testPoliteWordsCalmTheCrowdAndRoughOnesDoNot() {
        XCTAssertLessThan(VoicePhrase.sumimasen.alertCost, 0, "丁寧に言っても警戒が下がらない")
        XCTAssertGreaterThan(VoicePhrase.doke.alertCost, 0)
        XCTAssertTrue(VoicePhrase.doke.isRough)
        XCTAssertFalse(VoicePhrase.sumimasen.isRough)
    }

    func testRoughWordsMoveMorePeopleButRiskMore() {
        XCTAssertGreaterThan(
            VoicePhrase.doke.advanceRange.upperBound,
            VoicePhrase.sumimasen.advanceRange.upperBound,
            "強く言っても得がない"
        )
        XCTAssertGreaterThan(
            VoicePhrase.sumimasen.baseChance,
            VoicePhrase.doke.baseChance,
            "丁寧に言うほうが通りやすくないと選ぶ意味がない"
        )
    }

    func testVolumeIsClassifiedAcrossTheRange() {
        XCTAssertEqual(VoiceVolume.of(0.05), .quiet)
        XCTAssertEqual(VoiceVolume.of(0.3), .normal)
        XCTAssertEqual(VoiceVolume.of(0.6), .loud)
        XCTAssertEqual(VoiceVolume.of(0.95), .tooLoud)
    }

    /// 同じ言葉を続けると通らなくなること。
    func testRepeatingTheSamePhraseStopsWorking() {
        let person = PersonFactory.person(atQueueIndex: 3, scene: .shopping)

        func successes(repeatCount: Int) -> Int {
            (0..<300).filter { seed in
                BreakthroughResolver.resolve(
                    phrase: .doke, volume: .loud, person: person,
                    alertness: 0, repeatCount: repeatCount, remaining: 500, seed: seed
                ).succeeded
            }.count
        }

        XCTAssertGreaterThan(successes(repeatCount: 0), successes(repeatCount: 3))
    }

    /// 警戒されると乱暴な手が効かなくなること。
    func testAlertnessBlocksRoughTactics() {
        let person = PersonFactory.person(atQueueIndex: 8, scene: .shopping)

        func successes(alertness: Double) -> Int {
            (0..<300).filter { seed in
                BreakthroughResolver.resolve(
                    phrase: .doke, volume: .loud, person: person,
                    alertness: alertness, repeatCount: 0, remaining: 500, seed: seed
                ).succeeded
            }.count
        }

        XCTAssertGreaterThan(successes(alertness: 0), successes(alertness: 80))
    }

    func testGuardOnlyAppearsWhenAlertnessIsExtreme() {
        XCTAssertEqual(Alertness.guardChance(50), 0)
        XCTAssertEqual(Alertness.guardChance(84), 0)
        XCTAssertGreaterThan(Alertness.guardChance(100), 0)
    }

    func testAlertnessCoolsDownOverTime() {
        let later = Alertness.current(anchor: 60, anchorDate: noon, now: noon.addingTimeInterval(60))
        XCTAssertLessThan(later, 60)
        XCTAssertGreaterThanOrEqual(later, 0)
    }

    /// 進める人数が、残り人数を超えないこと。
    func testBreakthroughNeverOvershootsTheFront() {
        let person = PersonFactory.person(atQueueIndex: 1, scene: .shopping)
        for seed in 0..<200 {
            let outcome = BreakthroughResolver.resolve(
                phrase: .doke, volume: .loud, person: person,
                alertness: 0, repeatCount: 0, remaining: 3, seed: seed
            )
            XCTAssertLessThanOrEqual(outcome.advance, 3)
        }
    }

    // MARK: - 音

    /// 音源ファイルを持たないので、波形が正しく焼けることが前提になる。
    func testToneRendersAudibleSamples() throws {
        let buffer = try XCTUnwrap(ToneSynth.render(
            notes: [.init(frequency: 440, start: 0, duration: 0.2, volume: 0.5, timbre: .sine)],
            duration: 0.25
        ))

        XCTAssertEqual(Double(buffer.frameLength), 0.25 * ToneSynth.sampleRate, accuracy: 2)

        let channel = try XCTUnwrap(buffer.floatChannelData?[0])
        var peak: Float = 0
        for frame in 0..<Int(buffer.frameLength) {
            peak = max(peak, abs(channel[frame]))
            XCTAssertLessThanOrEqual(abs(channel[frame]), 1.0, "音が振り切れている")
        }
        XCTAssertGreaterThan(peak, 0.1, "音が鳴っていない")
    }

    func testEveryScenePicksAMood() {
        for scene in SceneKind.allCases {
            let mood = SceneMood.of(scene)
            XCTAssertGreaterThan(mood.beatDuration, 0)
            XCTAssertFalse(mood.chords.isEmpty)
            XCTAssertFalse(mood.scale.isEmpty)
        }
    }

    func testPitchFollowsTheOctave() {
        XCTAssertEqual(ToneSynth.pitch(semitonesFromA4: 0), 440, accuracy: 0.01)
        XCTAssertEqual(ToneSynth.pitch(semitonesFromA4: 12), 880, accuracy: 0.01)
    }

    // MARK: - ガチャ

    func testDropRatesAddUpToOneHundredPercent() {
        let total = GachaCatalog.items.reduce(0) { $0 + $1.dropRate }
        XCTAssertEqual(total, 1.0, accuracy: 0.0001, "排出率の合計が100%になっていない")
    }

    func testEveryItemIsReachableAndRoughlyMatchesItsRate() {
        var counts: [String: Int] = [:]
        var generator = SeededGenerator(seed: 20_260_731)

        let trials = 40_000
        for _ in 0..<trials {
            counts[GachaMachine.draw(using: &generator).id, default: 0] += 1
        }

        for item in GachaCatalog.items {
            let observed = Double(counts[item.id] ?? 0) / Double(trials)
            XCTAssertEqual(observed, item.dropRate, accuracy: 0.015,
                           "\(item.name)の排出率が設定から離れすぎている")
        }
    }

    /// 運が上がると高レアが出やすくなるか。
    func testLuckShiftsResultsTowardRarerItems() {
        func rareShare(luck: Double) -> Double {
            var generator = SeededGenerator(seed: 4_242)
            let trials = 20_000
            let rare = (0..<trials).filter { _ in
                GachaMachine.draw(luck: luck, using: &generator).rarity.glowStrength > 0.5
            }.count
            return Double(rare) / Double(trials)
        }

        XCTAssertGreaterThan(rareShare(luck: 0.5), rareShare(luck: 0))
    }

    func testCatalogHasTheFiveExpectedItems() {
        XCTAssertEqual(GachaCatalog.items.count, 5)
        XCTAssertEqual(GachaCatalog.item(id: "dash")?.people, 5)
        XCTAssertEqual(GachaCatalog.item(id: "bicycle")?.people, 20)
        XCTAssertEqual(GachaCatalog.item(id: "motorbike")?.people, 50)
        XCTAssertEqual(GachaCatalog.item(id: "car")?.people, 100)
        XCTAssertEqual(GachaCatalog.item(id: "train")?.people, 300)
    }

    /// 画面の中で数えるのではなく、保存した時刻から求めているかどうか。
    func testFreeGachaCooldownComesFromStoredTime() {
        XCTAssertNil(GachaMachine.remainingCooldown(lastDrawnAt: nil, now: noon))
        XCTAssertEqual(
            GachaMachine.remainingCooldown(lastDrawnAt: noon, now: noon.addingTimeInterval(600)) ?? 0,
            3_000,
            accuracy: 1
        )
        XCTAssertNil(GachaMachine.remainingCooldown(lastDrawnAt: noon, now: noon.addingTimeInterval(3_600)))
        XCTAssertNil(
            GachaMachine.remainingCooldown(lastDrawnAt: noon, now: noon.addingTimeInterval(86_400)),
            "閉じている間に何時間経っていても引ける"
        )
    }

    func testCooldownShortensWithEquipment() {
        let shortened = GachaMachine.remainingCooldown(
            lastDrawnAt: noon,
            now: noon,
            multiplier: 0.5
        ) ?? 0
        XCTAssertEqual(shortened, 1_800, accuracy: 1)
    }

    func testCountdownLabelIsMinutesAndSeconds() {
        XCTAssertEqual(GachaMachine.countdownLabel(2_538), "42:18")
        XCTAssertEqual(GachaMachine.countdownLabel(59), "00:59")
    }

    // MARK: - 前進の演出

    /// 抜いた人数によって、演出の強さが段階的に変わること。
    func testSurgeIntensityScalesWithPeople() {
        XCTAssertEqual(Surge.Tier.of(1), .slight)
        XCTAssertEqual(Surge.Tier.of(4), .slight)
        XCTAssertEqual(Surge.Tier.of(5), .moderate)
        XCTAssertEqual(Surge.Tier.of(14), .moderate)
        XCTAssertEqual(Surge.Tier.of(15), .strong)
        XCTAssertEqual(Surge.Tier.of(29), .strong)
        XCTAssertEqual(Surge.Tier.of(30), .massive)
        XCTAssertEqual(Surge.Tier.of(300), .massive)
    }

    /// 段階が上がるほど、演出が長く強くなること。
    func testStrongerSurgesLastLongerAndPushHarder() {
        let tiers: [Surge.Tier] = [.slight, .moderate, .strong, .massive]

        for (weaker, stronger) in zip(tiers, tiers.dropFirst()) {
            XCTAssertGreaterThan(stronger.duration, weaker.duration)
            XCTAssertGreaterThanOrEqual(stronger.cameraPush, weaker.cameraPush)
            XCTAssertGreaterThan(stronger.bannerSize, weaker.bannerSize)
        }

        XCTAssertTrue(Surge.Tier.massive.flashes)
        XCTAssertFalse(Surge.Tier.slight.flashes)
        XCTAssertTrue(Surge.Tier.strong.showsSpeedLines)
        XCTAssertFalse(Surge.Tier.moderate.showsSpeedLines)
    }

    /// テンポを殺さないよう、演出は2秒以内で終わること。
    func testSurgesNeverBlockPlayForTooLong() {
        for people in [1, 5, 20, 100, 300] {
            let surge = Surge(
                fromRemaining: 500, peopleSkipped: people, startedAt: noon,
                vehicle: nil, vehicleName: nil
            )
            XCTAssertLessThanOrEqual(surge.duration, 2.0, "\(people)人の演出が長すぎる")
        }
    }

    /// 数字は演出に合わせて減り、途中で戻らないこと。
    func testSurgeCountsDownSmoothlyWithoutGoingBackwards() {
        let surge = Surge(
            fromRemaining: 617, peopleSkipped: 19, startedAt: noon,
            vehicle: nil, vehicleName: nil
        )

        XCTAssertEqual(surge.displayedRemaining(at: noon), 617)
        XCTAssertEqual(surge.displayedRemaining(at: noon.addingTimeInterval(surge.duration)), 598)

        var previous = 618
        for step in stride(from: 0.0, through: surge.duration, by: 0.05) {
            let shown = surge.displayedRemaining(at: noon.addingTimeInterval(step))
            XCTAssertLessThanOrEqual(shown, previous, "数字が増えている")
            previous = shown
        }
    }

    /// 演出が終われば、カメラの寄りも必ず戻ること。
    func testCameraReturnsAfterTheSurge() {
        let surge = Surge(
            fromRemaining: 200, peopleSkipped: 40, startedAt: noon,
            vehicle: nil, vehicleName: nil
        )

        XCTAssertEqual(surge.cameraStrength(at: noon), 0, accuracy: 0.01)
        XCTAssertGreaterThan(surge.cameraStrength(at: noon.addingTimeInterval(surge.duration / 2)), 0.5)
        XCTAssertEqual(surge.cameraStrength(at: noon.addingTimeInterval(surge.duration)), 0, accuracy: 0.01)
        XCTAssertTrue(surge.isFinished(at: noon.addingTimeInterval(surge.duration)))
    }

    /// 乗り物を使ったときは、演出を長めに取ること。
    func testItemSurgesRunLongEnoughToSeeTheVehicle() {
        let onFoot = Surge(
            fromRemaining: 400, peopleSkipped: 100, startedAt: noon,
            vehicle: nil, vehicleName: nil
        )
        let byCar = Surge(
            fromRemaining: 400, peopleSkipped: 100, startedAt: noon,
            vehicle: .car, vehicleName: "車"
        )

        XCTAssertGreaterThan(byCar.duration, onFoot.duration)
        XCTAssertEqual(byCar.countedSoFar(at: noon), 0)
        XCTAssertEqual(byCar.countedSoFar(at: noon.addingTimeInterval(byCar.duration)), 100)

        var previous = 0
        for step in stride(from: 0.0, through: byCar.duration, by: 0.1) {
            let counted = byCar.countedSoFar(at: noon.addingTimeInterval(step))
            XCTAssertGreaterThanOrEqual(counted, previous, "カウンターが戻っている")
            previous = counted
        }
    }

    // MARK: - 保存

    /// 保存した項目を増やしても、古い記録が読めなくなってはいけない。
    func testOldSaveDataStillLoads() throws {
        let legacy = """
        {
          "joinedAt": 760000000,
          "lapStartedAt": 760000000,
          "anchorDate": 760000000,
          "anchorProgress": 7000,
          "lap": 2,
          "totalCutIns": 3,
          "totalSkipped": 0,
          "totalInteractions": 7,
          "nextTicketNumber": 2,
          "collected": []
        }
        """
        let state = try JSONDecoder().decode(QueueState.self, from: Data(legacy.utf8))

        XCTAssertEqual(state.stageNumber, 1)
        XCTAssertEqual(state.anchorProgress, 0, "数える対象が変わったので進捗は引き継がない")
        XCTAssertEqual(state.totalInteractions, 7, "遊んだ記録は残る")
        XCTAssertTrue(state.inventory.isEmpty)
        XCTAssertEqual(state.coins, 0)
    }

    // MARK: - 人と景品

    func testPeopleAreVariedButStable() {
        let first = PersonFactory.person(atQueueIndex: 431, scene: .shopping)
        let again = PersonFactory.person(atQueueIndex: 431, scene: .shopping)
        XCTAssertEqual(first, again, "同じ人が見るたびに変わってはいけない")

        let descriptors = Set((0..<400).map {
            PersonFactory.person(atQueueIndex: $0, scene: .shopping).descriptor
        })
        XCTAssertGreaterThan(descriptors.count, 60, "並んでいる人が似たり寄ったりで飽きる")
    }

    func testCrowdChangesWithTheScenery() {
        func types(in scene: SceneKind) -> Set<PersonType> {
            Set((0..<150).map { PersonFactory.person(atQueueIndex: $0, scene: scene).type })
        }

        XCTAssertTrue(types(in: .space).contains(.alien), "宇宙なのに宇宙人がいない")
        XCTAssertTrue(types(in: .heaven).contains(.angel), "天国なのに天使がいない")
        XCTAssertFalse(types(in: .residential).contains(.angel), "住宅街に天使がうろうろしている")
    }

    func testEveryPrizeIDIsUnique() {
        let ids = Set(PrizeCatalog.all.map(\.id))
        XCTAssertEqual(ids.count, PrizeCatalog.all.count, "景品IDが重複している")
    }
}
