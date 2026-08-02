import SwiftUI
import UIKit

/// 警戒が振り切れて、警備員に追われている場面。
///
/// **見つかった時点で終わりにはしない。** ここで逃げ切れば何も失わない。
/// そうしておかないと、危ない橋を渡る遊びかたが割に合わなくなる。
struct ChaseView: View {
    /// 失敗したときに戻される人数。先に見せて、逃げる理由をはっきりさせる。
    let penalty: Int
    let onFinish: (Bool) -> Void

    @Environment(SoundPlayer.self) private var sound

    @State private var startedAt = Date()
    @State private var hasFinished = false

    var body: some View {
        ZStack {
            background

            VStack(spacing: 18) {
                VStack(spacing: 6) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 40, weight: .black))
                        .foregroundStyle(.white)
                    Text("見つかった！")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("連打で振り切る。捕まると\(penalty)人ぶん戻される")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                }

                MashGame(target: 18, seconds: 4) { escaped in
                    finish(escaped)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .background(AppTheme.paper)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            startedAt = Date()
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            sound.play(.fail)
        }
    }

    /// 赤く脈打つ背景。数字を見なくても、まずいことが起きていると分かる。
    private var background: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(startedAt)
            let pulse = 0.5 + sin(t * 7) * 0.22

            ZStack {
                Color.black.opacity(0.86).ignoresSafeArea()

                RadialGradient(
                    colors: [.clear, Color(red: 0.90, green: 0.16, blue: 0.16).opacity(pulse)],
                    center: .center,
                    startRadius: 60,
                    endRadius: 420
                )
                .ignoresSafeArea()
            }
        }
    }

    private func finish(_ escaped: Bool) {
        guard !hasFinished else { return }
        hasFinished = true

        if escaped {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            sound.play(.great)
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            sound.play(.fail)
        }
        onFinish(escaped)
    }
}
