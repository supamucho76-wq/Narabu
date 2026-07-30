import AVFoundation
import Foundation

/// 音を波形から作る。
///
/// 音源ファイルを持たずに済ませるため、鳴らしたい音はすべてここで合成して
/// PCMバッファに焼く。焼いてしまえば、あとは再生するだけで済む。
enum ToneSynth {
    static let sampleRate: Double = 44_100

    static var format: AVAudioFormat {
        AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
            ?? AVAudioFormat()
    }

    /// ひとつの音。
    struct Note {
        /// 高さ（Hz）。
        let frequency: Double
        /// 鳴り始める時刻（秒）。
        let start: Double
        /// 鳴っている長さ（秒）。
        let duration: Double
        let volume: Double
        let timbre: Timbre
    }

    /// 音色。倍音の混ざりかたで表情が変わる。
    enum Timbre {
        /// やわらかい丸い音。
        case sine
        /// 少し硬い、電子音らしい音。
        case triangle
        /// ざらついた音。失敗や衝撃に使う。
        case noise
    }

    /// 音の列をバッファに焼く。
    static func render(notes: [Note], duration: Double) -> AVAudioPCMBuffer? {
        let format = format
        let frameCount = AVAudioFrameCount(max(1, duration * sampleRate))

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount

        for frame in 0..<Int(frameCount) {
            channel[frame] = 0
        }

        for note in notes {
            let startFrame = Int(note.start * sampleRate)
            let noteFrames = Int(note.duration * sampleRate)
            guard noteFrames > 0 else { continue }

            for offset in 0..<noteFrames {
                let frame = startFrame + offset
                guard frame >= 0, frame < Int(frameCount) else { continue }

                let t = Double(offset) / sampleRate
                let progress = Double(offset) / Double(noteFrames)
                let sample = wave(note.timbre, frequency: note.frequency, time: t, seed: frame)
                channel[frame] += Float(sample * envelope(progress) * note.volume)
            }
        }

        // 足し合わせで振り切れないように、全体をならす。
        normalize(channel, frameCount: Int(frameCount))
        return buffer
    }

    private static func wave(_ timbre: Timbre, frequency: Double, time: Double, seed: Int) -> Double {
        let phase = 2 * Double.pi * frequency * time

        switch timbre {
        case .sine:
            return sin(phase)
        case .triangle:
            // 基音に軽く倍音を混ぜる。
            return sin(phase) * 0.7 + sin(phase * 2) * 0.2 + sin(phase * 3) * 0.1
        case .noise:
            return (QueueEngine.unitRandom(seed, salt: 0x5EED) * 2 - 1) * 0.6
                + sin(phase) * 0.4
        }
    }

    /// 立ち上がりと減衰。ぶつ切りだとノイズが乗るので必ず通す。
    private static func envelope(_ progress: Double) -> Double {
        let attack = 0.02
        let release = 0.35

        if progress < attack { return progress / attack }
        if progress > 1 - release { return (1 - progress) / release }
        return 1
    }

    private static func normalize(_ channel: UnsafeMutablePointer<Float>, frameCount: Int) {
        var peak: Float = 0
        for frame in 0..<frameCount {
            peak = max(peak, abs(channel[frame]))
        }
        guard peak > 0.9 else { return }

        let scale = 0.9 / peak
        for frame in 0..<frameCount {
            channel[frame] *= scale
        }
    }

    // MARK: - 音階

    /// 音名から高さを求める。基準はA4 = 440Hz。
    static func pitch(semitonesFromA4 semitones: Int) -> Double {
        440 * pow(2, Double(semitones) / 12)
    }
}
