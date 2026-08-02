import AVFoundation
import Observation

/// 鳴らす音の種類。
enum SoundEffect: String, CaseIterable {
    case tap
    case success
    case great
    case fail
    case overtake
    case gacha
    case rare
    case clear
    /// 抽選を煽るチャイム。畳みかけて鳴らすと「チャンチャンチャン」になる。
    case chance
    /// 揃った瞬間のファンファーレ。
    case jackpot
}

/// 音を鳴らす係。
///
/// 音源ファイルは持たず、起動時に波形から作って持っておく。
/// 他のアプリの音楽を止めないよう、混ざる設定で鳴らす。
@MainActor
@Observable
final class SoundPlayer {
    private let engine = AVAudioEngine()
    private let effectNode = AVAudioPlayerNode()
    private let musicNode = AVAudioPlayerNode()

    private var effects: [SoundEffect: AVAudioPCMBuffer] = [:]
    private var musicBuffers: [SceneMood: AVAudioPCMBuffer] = [:]
    /// 連続成功で1段ずつ上がっていく音。あらかじめ全部の高さを焼いておく。
    private var steps: [AVAudioPCMBuffer?] = []
    private var currentMood: SceneMood?
    private var isRunning = false

    /// 上がっていく音の並び。長調の音階なので、続けて鳴らすと駆け上がって聞こえる。
    /// 最後は2オクターブ上まで行き、そこで頭打ちにする。
    private static let stepScale: [Int] = [
        0, 2, 4, 5, 7, 9, 11, 12,
        14, 16, 17, 19, 21, 23, 24, 26,
        28, 29, 31, 33, 35, 36
    ]

    /// 効果音を鳴らすか。
    var isEffectEnabled = true {
        didSet { UserDefaults.standard.set(isEffectEnabled, forKey: "soundEffectEnabled") }
    }

    /// BGMを流すか。
    var isMusicEnabled = true {
        didSet {
            UserDefaults.standard.set(isMusicEnabled, forKey: "musicEnabled")
            if isMusicEnabled {
                if let currentMood { play(mood: currentMood, force: true) }
            } else {
                musicNode.stop()
            }
        }
    }

    init() {
        let defaults = UserDefaults.standard
        isEffectEnabled = defaults.object(forKey: "soundEffectEnabled") as? Bool ?? true
        isMusicEnabled = defaults.object(forKey: "musicEnabled") as? Bool ?? true

        guard !AppRuntime.isUITesting else { return }
        prepare()
    }

    // MARK: - 準備

    private func prepare() {
        // 他のアプリの音楽を止めず、消音スイッチにも従う。
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)

        let format = ToneSynth.format
        engine.attach(effectNode)
        engine.attach(musicNode)
        engine.connect(effectNode, to: engine.mainMixerNode, format: format)
        engine.connect(musicNode, to: engine.mainMixerNode, format: format)

        effectNode.volume = 0.55
        musicNode.volume = 0.16

        do {
            try engine.start()
            effectNode.play()
            isRunning = true
        } catch {
            // 音が出せなくても遊べるほうが大事なので、黙って諦める。
            isRunning = false
        }

        for effect in SoundEffect.allCases {
            effects[effect] = Self.buffer(for: effect)
        }
        steps = Self.stepScale.map { Self.stepBuffer(semitonesFromA4: $0) }
    }

    // MARK: - 効果音

    func play(_ effect: SoundEffect) {
        guard isRunning, isEffectEnabled, let buffer = effects[effect] else { return }
        effectNode.scheduleBuffer(buffer, at: nil, options: .interrupts)
    }

    /// 連続で成功しているあいだ、音程を1段ずつ上げて鳴らす。
    ///
    /// **同じ音が続くと、何回押しても同じことをしている感じになる。**
    /// 一段ずつ上がっていくと、押すたびに積み上がっている音になり、
    /// 途切れさせたくなくなる。気持ちよさのいちばん安い作りかた。
    func playStep(_ step: Int) {
        guard isRunning, isEffectEnabled, !steps.isEmpty else { return }
        let buffer = steps[min(max(0, step), steps.count - 1)]
        guard let buffer else { return }
        effectNode.scheduleBuffer(buffer, at: nil, options: .interrupts)
    }

    // MARK: - BGM

    /// 場面に合わせて曲を切り替える。同じ気分のあいだは鳴らし続ける。
    func play(mood: SceneMood, force: Bool = false) {
        guard isRunning, isMusicEnabled else {
            currentMood = mood
            return
        }
        guard force || mood != currentMood else { return }

        currentMood = mood

        let buffer = musicBuffers[mood] ?? Self.musicBuffer(for: mood)
        musicBuffers[mood] = buffer
        guard let buffer else { return }

        musicNode.stop()
        musicNode.scheduleBuffer(buffer, at: nil, options: .loops)
        musicNode.play()
    }

    // MARK: - 録音のあいだ譲る

    /// マイクを使うあいだ、こちらのエンジンを完全に止めて場所を空ける。
    ///
    /// 録音に切り替わるとハードウェアの形式が変わることがあり、
    /// 動いたままの再生エンジンは繋ぎ直しに失敗して落ちる。
    /// 一時停止では足りないので、資源ごと手放す。
    func suspendForRecording() {
        guard isRunning else { return }
        musicNode.stop()
        effectNode.stop()
        engine.stop()
        isRunning = false
    }

    /// 録音が終わったら、繋ぎ直してから鳴らし始める。
    func resumeAfterRecording() {
        guard !isRunning else { return }

        let format = ToneSynth.format
        engine.connect(effectNode, to: engine.mainMixerNode, format: format)
        engine.connect(musicNode, to: engine.mainMixerNode, format: format)

        do {
            try engine.start()
            effectNode.play()
            isRunning = true

            if isMusicEnabled, let mood = currentMood {
                currentMood = nil
                play(mood: mood)
            }
        } catch {
            // 鳴らせなくても遊びは続けられる。
            isRunning = false
        }
    }

    // MARK: - 音作り

    /// 連続成功の一打ち。短く、粒立ちよく。
    private static func stepBuffer(semitonesFromA4: Int) -> AVAudioPCMBuffer? {
        ToneSynth.render(
            notes: [
                .init(frequency: ToneSynth.pitch(semitonesFromA4: semitonesFromA4), start: 0,
                      duration: 0.09, volume: 0.5, timbre: .triangle),
                // オクターブ上を薄く重ねると、粒が立って抜けがよくなる。
                .init(frequency: ToneSynth.pitch(semitonesFromA4: semitonesFromA4 + 12), start: 0,
                      duration: 0.07, volume: 0.18, timbre: .sine)
            ],
            duration: 0.13
        )
    }

    private static func buffer(for effect: SoundEffect) -> AVAudioPCMBuffer? {
        switch effect {
        case .tap:
            return ToneSynth.render(
                notes: [.init(frequency: ToneSynth.pitch(semitonesFromA4: 3), start: 0,
                              duration: 0.07, volume: 0.5, timbre: .triangle)],
                duration: 0.09
            )

        case .success:
            // 短い上がり。
            return ToneSynth.render(
                notes: [
                    .init(frequency: ToneSynth.pitch(semitonesFromA4: 0), start: 0,
                          duration: 0.09, volume: 0.5, timbre: .triangle),
                    .init(frequency: ToneSynth.pitch(semitonesFromA4: 7), start: 0.07,
                          duration: 0.12, volume: 0.5, timbre: .triangle)
                ],
                duration: 0.22
            )

        case .great:
            return ToneSynth.render(
                notes: [
                    .init(frequency: ToneSynth.pitch(semitonesFromA4: 4), start: 0,
                          duration: 0.09, volume: 0.5, timbre: .triangle),
                    .init(frequency: ToneSynth.pitch(semitonesFromA4: 9), start: 0.07,
                          duration: 0.09, volume: 0.5, timbre: .triangle),
                    .init(frequency: ToneSynth.pitch(semitonesFromA4: 16), start: 0.14,
                          duration: 0.18, volume: 0.45, timbre: .triangle)
                ],
                duration: 0.36
            )

        case .fail:
            // 下がって終わる。
            return ToneSynth.render(
                notes: [
                    .init(frequency: ToneSynth.pitch(semitonesFromA4: -5), start: 0,
                          duration: 0.12, volume: 0.45, timbre: .triangle),
                    .init(frequency: ToneSynth.pitch(semitonesFromA4: -10), start: 0.1,
                          duration: 0.2, volume: 0.4, timbre: .triangle)
                ],
                duration: 0.34
            )

        case .overtake:
            // 走り抜ける風。
            return ToneSynth.render(
                notes: (0..<8).map { step in
                    .init(
                        frequency: 220 + Double(step) * 90,
                        start: Double(step) * 0.035,
                        duration: 0.12,
                        volume: 0.34,
                        timbre: .noise
                    )
                },
                duration: 0.44
            )

        case .gacha:
            return ToneSynth.render(
                notes: (0..<5).map { step in
                    .init(
                        frequency: ToneSynth.pitch(semitonesFromA4: 0 + step * 2),
                        start: Double(step) * 0.06,
                        duration: 0.1,
                        volume: 0.4,
                        timbre: .sine
                    )
                },
                duration: 0.42
            )

        case .rare:
            // 高レア用。上へ駆け上がる。
            return ToneSynth.render(
                notes: (0..<10).map { step in
                    .init(
                        frequency: ToneSynth.pitch(semitonesFromA4: step * 2),
                        start: Double(step) * 0.05,
                        duration: 0.16,
                        volume: 0.42,
                        timbre: .triangle
                    )
                },
                duration: 0.72
            )

        case .clear:
            let chord = [0, 4, 7, 12]
            return ToneSynth.render(
                notes: chord.enumerated().map { index, semitone in
                    .init(
                        frequency: ToneSynth.pitch(semitonesFromA4: semitone),
                        start: Double(index) * 0.08,
                        duration: 0.6,
                        volume: 0.4,
                        timbre: .triangle
                    )
                },
                duration: 1.0
            )

        case .chance:
            // 「チャン」の一打ち。畳みかけて鳴らすとあの音になる。
            // 5度を重ねると、単音より telegraph めいた鳴りかたになる。
            return ToneSynth.render(
                notes: [
                    .init(frequency: ToneSynth.pitch(semitonesFromA4: 12), start: 0,
                          duration: 0.11, volume: 0.42, timbre: .square),
                    .init(frequency: ToneSynth.pitch(semitonesFromA4: 19), start: 0,
                          duration: 0.11, volume: 0.26, timbre: .square)
                ],
                duration: 0.14
            )

        case .jackpot:
            // 揃った瞬間。駆け上がってから和音で押し切る。
            var notes: [ToneSynth.Note] = (0..<12).map { step in
                .init(
                    frequency: ToneSynth.pitch(semitonesFromA4: -12 + step * 3),
                    start: Double(step) * 0.045,
                    duration: 0.12,
                    volume: 0.4,
                    timbre: .square
                )
            }
            for (index, semitone) in [0, 4, 7, 12, 16].enumerated() {
                notes.append(.init(
                    frequency: ToneSynth.pitch(semitonesFromA4: semitone),
                    start: 0.55 + Double(index) * 0.03,
                    duration: 0.7,
                    volume: 0.38,
                    timbre: .triangle
                ))
            }
            return ToneSynth.render(notes: notes, duration: 1.4)
        }
    }

    /// 場面ごとのBGM。同じ作りで、根音と速さだけ変える。
    private static func musicBuffer(for mood: SceneMood) -> AVAudioPCMBuffer? {
        let beat = mood.beatDuration
        let bars = 4
        let stepsPerBar = 8
        let total = beat * Double(bars * stepsPerBar)

        var notes: [ToneSynth.Note] = []

        for bar in 0..<bars {
            let chord = mood.chords[bar % mood.chords.count]

            // 低音。1小節に1回だけ、長く。
            notes.append(.init(
                frequency: ToneSynth.pitch(semitonesFromA4: mood.root + chord - 24),
                start: Double(bar * stepsPerBar) * beat,
                duration: beat * Double(stepsPerBar) * 0.9,
                volume: 0.30,
                timbre: .sine
            ))

            // 上物。和音の構成音をゆっくり行き来する。
            for step in 0..<stepsPerBar where step % 2 == 0 {
                let degree = mood.scale[(bar * 3 + step / 2) % mood.scale.count]
                notes.append(.init(
                    frequency: ToneSynth.pitch(semitonesFromA4: mood.root + chord + degree),
                    start: Double(bar * stepsPerBar + step) * beat,
                    duration: beat * 1.6,
                    volume: 0.16,
                    timbre: .sine
                ))
            }
        }

        return ToneSynth.render(notes: notes, duration: total)
    }
}

/// 場面の気分。BGMの調と速さを決める。
enum SceneMood: String, CaseIterable, Sendable {
    case town
    case nature
    case festive
    case cold
    case vast
    case ominous
    case serene

    /// 根音。高いほど明るく聞こえる。
    var root: Int {
        switch self {
        case .town: 0
        case .nature: -3
        case .festive: 4
        case .cold: -1
        case .vast: -5
        case .ominous: -8
        case .serene: 5
        }
    }

    /// 1拍の長さ。長いほどゆったりする。
    var beatDuration: Double {
        switch self {
        case .festive: 0.28
        case .town: 0.34
        case .nature: 0.40
        case .cold: 0.44
        case .vast, .serene: 0.52
        case .ominous: 0.38
        }
    }

    /// 小節ごとの和音。
    var chords: [Int] {
        switch self {
        case .ominous: [0, -2, -5, -3]
        case .serene: [0, 5, 3, 7]
        default: [0, 5, -3, 3]
        }
    }

    /// 使う音階。暗い場面では短調寄りにする。
    var scale: [Int] {
        switch self {
        case .ominous, .cold: [0, 3, 7, 10, 12]
        case .vast: [0, 2, 7, 9, 12]
        default: [0, 4, 7, 9, 12]
        }
    }

    /// 場所から気分を決める。
    static func of(_ scene: SceneKind) -> SceneMood {
        switch scene {
        case .residential, .shopping, .hall: .town
        case .forest, .sea: .nature
        case .park, .night, .ramen: .festive
        case .snow: .cold
        case .desert, .space: .vast
        case .hell: .ominous
        case .heaven: .serene
        }
    }
}
