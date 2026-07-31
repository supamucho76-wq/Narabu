import AVFoundation
import Observation
import Speech

/// 声を聞き取る係。
///
/// 押している間だけ聞き、離したら止める。認識した文はその場で判定に使うだけで、
/// どこにも保存しないし送らない。使えない環境でも遊びが止まらないよう、
/// 失敗はすべて黙って飲み込んで「使えない」状態に落とす。
@MainActor
@Observable
final class VoiceRecognizer {
    enum Availability: Equatable {
        /// まだ許可を求めていない。
        case notAsked
        case ready
        /// 断られた、または端末が対応していない。
        case unavailable(String)
    }

    private(set) var availability: Availability = .notAsked
    private(set) var isListening = false
    /// いま聞き取れている文。画面に短く出す。
    private(set) var transcript = ""
    /// いまの声の強さ。0から1。
    private(set) var level: Double = 0

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var peakLevel: Double = 0

    var canListen: Bool { availability == .ready }

    // MARK: - 許可

    /// 機能の説明を見せたあとに呼ぶ。いきなりダイアログを出さない。
    func requestPermission() async {
        guard let recognizer, recognizer.isAvailable else {
            availability = .unavailable("この端末では音声認識を使えません")
            return
        }

        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else {
            availability = .unavailable("音声認識が許可されていません")
            return
        }

        let micGranted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        guard micGranted else {
            availability = .unavailable("マイクが許可されていません")
            return
        }

        availability = .ready
    }

    // MARK: - 聞き取り

    func start() {
        guard canListen, !isListening else { return }

        transcript = ""
        level = 0
        peakLevel = 0

        // BGMを鳴らしたまま録音するため、混ざる設定にする。
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement,
                                    options: [.mixWithOthers, .defaultToSpeaker])
            try session.setActive(true)
        } catch {
            availability = .unavailable("マイクを使えませんでした")
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // 端末の中だけで処理する。声を外に出さない。
        request.requiresOnDeviceRecognition = recognizer?.supportsOnDeviceRecognition ?? false
        self.request = request

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else {
            stopAudio()
            availability = .unavailable("マイクを使えませんでした")
            return
        }

        input.installTap(onBus: 0, bufferSize: 1_024, format: format) { [weak self] buffer, _ in
            request.append(buffer)
            let power = Self.power(of: buffer)
            Task { @MainActor in self?.updateLevel(power) }
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            stopAudio()
            availability = .unavailable("マイクを使えませんでした")
            return
        }

        task = recognizer?.recognitionTask(with: request) { [weak self] result, _ in
            guard let result else { return }
            let text = result.bestTranscription.formattedString
            Task { @MainActor in self?.transcript = text }
        }

        isListening = true
    }

    /// 聞き取りを止めて、判定に使う材料を返す。
    @discardableResult
    func stop() -> (transcript: String, volume: VoiceVolume) {
        guard isListening else { return ("", .normal) }

        let heard = transcript
        let volume = VoiceVolume.of(peakLevel)

        stopAudio()
        isListening = false
        level = 0
        // 聞き取った文はここで捨てる。
        transcript = ""

        return (heard, volume)
    }

    private func stopAudio() {
        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning { engine.stop() }

        request?.endAudio()
        request = nil
        task?.cancel()
        task = nil

        // BGMだけの状態に戻す。
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func updateLevel(_ power: Double) {
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
