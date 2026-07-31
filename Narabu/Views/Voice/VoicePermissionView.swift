import SwiftUI
import UIKit

/// 声を使う前に、何のために使うのかを説明する画面。
///
/// 起動していきなり許可を求めると断られるので、必ずここを挟む。
struct VoicePermissionView: View {
    @Environment(VoiceRecognizer.self) private var voice
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "mic.fill")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.stamp)

            VStack(spacing: 8) {
                Text("声で列を進めます")
                    .font(.headline)
                Text("「すみません！」「どけ！」など、実際に声を出すと前の人たちが動きます。\n言いかたと声の大きさで結果が変わります。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 10) {
                note(symbol: "waveform", text: "ボタンを押している間だけ聞き取ります")
                note(symbol: "iphone", text: "聞き取りは端末の中だけで行います")
                note(symbol: "trash", text: "聞き取った声は保存も送信もしません")
                note(symbol: "hand.raised", text: "声を出せないときは「無言」で同じように遊べます")
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.ink.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            if let reason = voice.unavailableReason {
                VStack(spacing: 4) {
                    Text(reason)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(red: 0.78, green: 0.28, blue: 0.24))
                    if voice.needsSettings {
                        Text("設定アプリの「ならぶ」から、マイクと音声認識をオンにすると使えます。")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: 8) {
                if voice.needsSettings {
                    Button {
                        openSettings()
                    } label: {
                        Text("設定を開く")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(AppTheme.stamp)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                } else {
                    Button {
                        Task {
                            await voice.requestPermission()
                            if voice.canListen { dismiss() }
                        }
                    } label: {
                        Text("マイクを許可する")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(AppTheme.stamp)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }

                Button("使わずに遊ぶ") { dismiss() }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 24)
        .background(AppTheme.paper.ignoresSafeArea())
        .foregroundStyle(AppTheme.ink)
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func note(symbol: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .frame(width: 20)
                .foregroundStyle(AppTheme.stamp)
            Text(text)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}
