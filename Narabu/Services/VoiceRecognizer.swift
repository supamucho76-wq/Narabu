import AVFoundation
import Observation
import Speech

/// 声を聞き取る係。
///
/// 押している間だけ聞き、離したら止める。認識した文はその場で判定に使うだけで、
/// どこにも保存しないし送らない。
///
/// 実機では、マイクが他に取られていたり権限が無かったりと失敗する道が多い。
/// どこで転んでも必ず元の画面に戻れるよう、危ない処理はすべて確認と後始末で挟む。
@MainActor
@Observable
final class VoiceRecognizer {
    enum Availability: Equatable {
        /// まだ許可を求めていない。
        case notAsked
        case ready
        /// 使えない。理由と、設定アプリで直せるかどうかを持つ。
        case unavailable(reason: String, canOpenSettings: Bool)
    }

    private(set) var availability: Availability = .notAsked
    private(set) var isListening = false
    /// 起動処理の最中。連打による二重起動を防ぐ。
    private(set) var isStarting = false
    /// いま聞き取れている文。画面に短く出す。
    private(set) var transcript = ""
    /// いまの声の強さ。0から1。
    private(set) var level: Double = 0

    /// マイクを使うあいだ、BGMに場所を空けてもらう。
    var onWillRecord: (() -> Void)?
    var onDidFinishRecording: (() -> Void)?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    /// エンジンは毎回作り直す。前回の状態を持ち越すと実機で不安定になる。
    private var engine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var peakLevel: Double = 0

    var canListen: Bool { availability == .ready && !isStarting }

    /// 設定アプリを開いて直せる状態かどうか。
    var needsSettings: Bool {
        if case .unavailable(_, let canOpenSettings) = availability { return canOpenSettings }
        return false
    }

    var unavailableReason: String? {
        if case .unavailable(let reason, _) = availability { return reason }
        return nil
    }

    init() {
        guard !AppRuntime.isUITesting else { return }
        refreshAvailability()
    }

    // MARK: - 許可

    /// すでに答えが出ている権限だけを見て、状態を更新する。ダイアログは出さない。
    func refreshAvailability() {
        guard let recognizer, recognizer.isAvailable else {
            availability = .unavailable(reason: "この端末では音声認識を使えません", canOpenSettings: false)
            return
        }

        switch SFSpeechRecognizer.authorizationStatus() {
        case .denied, .restricted:
            availability = .unavailable(reason: "音声認識が許可されていません", canOpenSettings: true)
            return
        case .authorized:
            break
        case .notDetermined:
            availability = .notAsked
            return
        @unknown default:
            availability = .notAsked
            return
        }

        switch AVAudioApplication.shared.recordPermission {
        case .denied:
            availability = .unavailable(reason: "マイクが許可されていません", canOpenSettings: true)
        case .granted:
            availability = .ready
        case .undetermined:
            availability = .notAsked
        @unknown default:
            availability = .notAsked
        }
    }

    /// 機能の説明を見せたあとに呼ぶ。いきなりダイアログを出さない。
    func requestPermission() async {
        guard let recognizer, recognizer.isAvailable else {
            availability = .unavailable(reason: "この端末では音声認識を使えません", canOpenSettings: false)
            return
        }

        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard speechStatus == .authorized else {
            availability = .unavailable(reason: "音声認識が許可されていません", canOpenSettings: true)
            return
        }

        let micGranted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
        guard micGranted else {
            availability = .unavailable(reason: "マイクが許可されていません", canOpenSettings: true)
            return
        }

        availability = .ready
    }

    // MARK: - 聞き取り

    /// 聞き取りを始める。始められたかどうかを返す。
    @discardableResult
    func start() -> Bool {
        // 連打しても二重に走らせない。
        guard !isListening, !isStarting else { return false }

        // エンジンに触る前に、権限が揃っていることを確かめる。
        refreshAvailability()
        guard availability == .ready, let recognizer else { return false }

        isStarting = true
        defer { isStarting = false }

        transcript = ""
        level = 0
        peakLevel = 0

        // BGMのエンジンを止めてもらってから、録音用のセッションに移る。
        onWillRecord?()

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement,
                                    options: [.mixWithOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            fail(reason: "マイクを使えませんでした")
            return false
        }

        let engine = AVAudioEngine()
        self.engine = engine

        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        // 形式が揃っていないまま tap を付けると実機で落ちる。
        guard format.sampleRate > 0, format.channelCount > 0 else {
            fail(reason: "マイクを使えませんでした")
            return false
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // 端末の中だけで処理する。声を外に出さない。
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        self.request = request

        // 前回の tap が残っていることがあるので、必ず外してから付ける。
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1_024, format: format) { [weak self] buffer, _ in
            request.append(buffer)
            let power = Self.power(of: buffer)
            Task { @MainActor [weak self] in self?.updateLevel(power) }
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            fail(reason: "マイクを使えませんでした")
            return false
        }

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let result else {
                if error != nil {
                    Task { @MainActor [weak self] in self?.handleRecognitionFailure() }
                }
                return
            }
            let text = result.bestTranscription.formattedString
            Task { @MainActor [weak self] in self?.transcript = text }
        }

        isListening = true
        return true
    }

    /// 聞き取りを止めて、判定に使う材料を返す。
    @discardableResult
    func stop() -> (transcript: String, volume: VoiceVolume) {
        guard isListening else { return ("", .normal) }

        let heard = transcript
        let volume = VoiceVolume.of(peakLevel)

        teardown()
        // 聞き取った文はここで捨てる。
        transcript = ""

        return (heard, volume)
    }

    // MARK: - 後始末

    /// 途中で転んだときも、必ずここを通って元の状態に戻す。
    private func fail(reason: String) {
        teardown()
        availability = .unavailable(reason: reason, canOpenSettings: true)
    }

    /// 認識そのものが失敗したときは、使えない状態にはせず黙って閉じる。
    private func handleRecognitionFailure() {
        guard isListening else { return }
        teardown()
    }

    private func teardown() {
        if let engine {
            engine.inputNode.removeTap(onBus: 0)
            if engine.isRunning { engine.stop() }
        }
        engine = nil

        request?.endAudio()
        request = nil
        task?.cancel()
        task = nil

        isListening = false
        level = 0
        peakLevel = 0

        // BGMだけの状態に戻す。
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        onDidFinishRecording?()
    }

    private func updateLevel(_ power: Double) {
        guard isListening else { return }
        level = power
        peakLevel = max(peakLevel, power)
    }

    /// バッファの音の強さを、0から1のおおまかな値にする。
    private static func power(of buffer: AVAudioPCMBuffer) -> Double {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return 0 }

        var sum: Double = 0
        for frame in 0..<frames {
            let sample = Double(channel[frame])
            sum += sample * sample
        }

        let rms = (sum / Double(frames)).squareRoot()
        // 小さい音が潰れないよう、対数で伸ばす。
        let decibels = 20 * log10(max(rms, 0.000_01))
        return min(1, max(0, (decibels + 50) / 45))
    }
}
