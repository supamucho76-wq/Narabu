import SwiftUI
import UIKit

/// 声、または指で前へ押し通すための操作。
///
/// 押している間だけ聞き取り、長押しすると声を出さずに強さを決められる。
/// どちらでも効果は変わらないので、外でも家でも同じように遊べる。
struct VoiceControl: View {
    @Environment(VoiceRecognizer.self) private var voice

    /// 声で押し通したときに呼ばれる。
    let onVoice: (VoicePhrase, VoiceVolume) -> Void
    /// 無言で押し通したときに呼ばれる。
    let onSilent: (VoicePhrase, VoiceVolume) -> Void
    /// 権限の説明を出したいとき。
    let onNeedsPermission: () -> Void

    /// 声を使うかどうか。実機で安定するまでは既定で切ってある。
    @AppStorage("isVoiceEnabled") private var isVoiceEnabled = false

    @State private var mode: Mode = .idle
    @State private var silentPhrase: VoicePhrase = .sumimasen
    @State private var gaugeStoppedAt: Date?

    private enum Mode: Equatable {
        case idle
        /// 声を聞いている。
        case listening
        /// 無言で強さを決めている。
        case charging
    }

    var body: some View {
        VStack(spacing: 8) {
            switch mode {
            case .idle:
                idleButton
            case .listening:
                listeningPanel
            case .charging:
                chargingPanel
            }
        }
        .onChange(of: voice.isListening) { _, listening in
            // 途中で聞き取りが止まったら、その画面に取り残されないようにする。
            if !listening, mode == .listening { mode = .idle }
        }
    }

    // MARK: - ふだんの見た目

    private var idleButton: some View {
        HStack(spacing: 8) {
            Button {
                beginSilent()
            } label: {
                Label("押し通す", systemImage: "figure.walk.motion")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .background(AppTheme.stamp)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            // 声は実機で安定を確かめてから出す。既定では表示しない。
            if isVoiceEnabled {
                Button {
                    beginVoice()
                } label: {
                    Label("声", systemImage: "mic.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                        .frame(minWidth: 76, maxWidth: 76, minHeight: 42)
                        .background(AppTheme.paper.opacity(0.94))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .disabled(voice.isStarting)
            }
        }
    }

    // MARK: - 聞き取り中

    private var listeningPanel: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                // 聞いていることが目で分かるようにする。
                Circle()
                    .fill(Color(red: 0.94, green: 0.34, blue: 0.30))
                    .frame(width: 8, height: 8)
                    .opacity(voice.level > 0.1 ? 1 : 0.4)

                Text(voice.transcript.isEmpty ? "聞いています…" : voice.transcript)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)

                Spacer()

                Text(VoiceVolume.of(voice.level).label)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }

            levelMeter(voice.level)

            Button {
                endVoice()
            } label: {
                Text("離す")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .background(AppTheme.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(10)
        .background(AppTheme.paper.opacity(0.96))
        .foregroundStyle(AppTheme.ink)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - 無言モード

    private var chargingPanel: some View {
        VStack(spacing: 8) {
            HStack {
                Text("言いかた")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(silentPhrase.label)
                    .font(.caption.weight(.bold))
            }

            // 言葉を選ぶ。声のときと同じ選択肢。
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(VoicePhrase.allCases, id: \.self) { phrase in
                        Button {
                            silentPhrase = phrase
                        } label: {
                            Text(phrase.label)
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(silentPhrase == phrase ? AppTheme.stamp : AppTheme.ink.opacity(0.08))
                                .foregroundStyle(silentPhrase == phrase ? .white : AppTheme.ink)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            TimelineView(.animation) { timeline in
                let strength = Self.gaugeStrength(at: gaugeStoppedAt ?? timeline.date)

                VStack(spacing: 4) {
                    levelMeter(strength)
                    Text(VoiceVolume.of(strength).label)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                Button("やめる") { mode = .idle }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    endSilent()
                } label: {
                    Text("この強さで言う")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(AppTheme.stamp)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .padding(10)
        .background(AppTheme.paper.opacity(0.96))
        .foregroundStyle(AppTheme.ink)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func levelMeter(_ value: Double) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(AppTheme.ink.opacity(0.1))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.52, green: 0.78, blue: 0.60),
                                Color(red: 0.94, green: 0.76, blue: 0.30),
                                Color(red: 0.92, green: 0.36, blue: 0.30)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(3, geometry.size.width * min(1, max(0, value))))
            }
        }
        .frame(height: 8)
    }

    /// ゲージは時刻から決まるので、状態を毎フレーム書き換えなくて済む。
    private static func gaugeStrength(at date: Date) -> Double {
        let t = date.timeIntervalSince1970 * 1.1
        return 1 - abs(t.truncatingRemainder(dividingBy: 2) - 1)
    }

    // MARK: - 進行

    private func beginVoice() {
        guard voice.canListen else {
            onNeedsPermission()
            return
        }
        // 始められなかったときは聞き取り画面に入らない。入ると出られなくなる。
        guard voice.start() else {
            onNeedsPermission()
            return
        }
        mode = .listening
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func endVoice() {
        let heard = voice.stop()
        mode = .idle

        guard let phrase = VoicePhrase.match(in: heard.transcript) else {
            // 何も聞き取れなかったときは、何も起こさない。
            return
        }
        onVoice(phrase, heard.volume)
    }

    private func beginSilent() {
        gaugeStoppedAt = nil
        mode = .charging
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func endSilent() {
        let now = Date()
        gaugeStoppedAt = now
        let strength = Self.gaugeStrength(at: now)
        mode = .idle
        onSilent(silentPhrase, VoiceVolume.of(strength))
    }
}
