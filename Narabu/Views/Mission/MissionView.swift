import SwiftUI
import UIKit

/// ミッションを遊ぶ画面。
///
/// 遊びかたそのものは種類ごとの小さな画面に任せ、ここは枠と結果だけを持つ。
/// 失敗しても必ずここから出られるよう、自動で閉じる処理とボタンの両方を残す。
struct MissionView: View {
    let mission: Mission
    /// 成功したら実際に進む人数。連続成功の倍率がかかった値。
    let reward: Int
    /// 成否を親に返す。列を進めるのは親の仕事。
    let onFinish: (Bool) -> Void

    @State private var verdict: Bool?
    /// 二重に閉じないための印。
    @State private var hasClosed = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 18) {
                header

                if let verdict {
                    result(success: verdict)
                    closeButton(success: verdict)
                } else {
                    game
                }
            }
            .padding(22)
            .background(AppTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 20)
            .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
        }
    }

    // MARK: - 見出し

    private var header: some View {
        VStack(spacing: 5) {
            Text("ミッション")
                .font(.system(size: 10, weight: .black))
                .tracking(3)
                .foregroundStyle(AppTheme.stamp)
            Text(mission.title)
                .font(.headline)
            Text(mission.instruction)
                .font(.caption)
                .foregroundStyle(AppTheme.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(AppTheme.ink)
    }

    // MARK: - 遊びかた

    @ViewBuilder
    private var game: some View {
        switch mission.kind {
        case .timing(let width, let speed):
            TimingGame(targetWidth: width, speed: speed, onFinish: finish)
        case .mash(let taps, let seconds):
            MashGame(target: taps, seconds: seconds, onFinish: finish)
        case .swipe(let count, let seconds):
            SwipeGame(count: count, seconds: seconds, onFinish: finish)
        case .jump(let speed, let window):
            JumpGame(speed: speed, window: window, onFinish: finish)
        case .dodge(let seconds):
            DodgeGame(seconds: seconds, onFinish: finish)
        case .escalator(let seconds):
            EscalatorGame(seconds: seconds, onFinish: finish)
        case .hide(let seconds):
            HideGame(seconds: seconds, onFinish: finish)
        case .align(let tolerance):
            AlignGame(tolerance: tolerance, onFinish: finish)
        case .hold(let target, let tolerance):
            HoldGame(target: target, tolerance: tolerance, onFinish: finish)
        case .pluck(let count, let seconds):
            PluckGame(count: count, seconds: seconds, onFinish: finish)
        case .weave(let count, let seconds):
            WeaveGame(count: count, seconds: seconds, onFinish: finish)
        case .trace(let seconds, let width):
            TraceGame(seconds: seconds, width: width, onFinish: finish)
        case .balance(let seconds, let drift):
            BalanceGame(seconds: seconds, drift: drift, onFinish: finish)
        }
    }

    // MARK: - 結果

    private func result(success: Bool) -> some View {
        VStack(spacing: 10) {
            Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle")
                .font(.system(size: 38))
                .foregroundStyle(success ? AppTheme.stamp : AppTheme.inkSecondary)

            Text(success ? "成功" : "惜しい")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.ink)

            if success {
                Text("\(reward)人 前へ進んだ　＋\(mission.coins)コイン")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.inkSecondary)
            } else {
                Text("すぐ次に挑戦できます")
                    .font(.caption)
                    .foregroundStyle(AppTheme.inkSecondary)
            }
        }
    }

    /// 自動で閉じられなかったときのための、確実な逃げ道。
    private func closeButton(success: Bool) -> some View {
        Button {
            close(success: success)
        } label: {
            Text("続ける")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: AppTheme.minimumTapHeight)
                .background(AppTheme.ink)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(GameButtonStyle())
    }

    // MARK: - 進行

    /// 遊びが終わったときに、種類ごとの画面から呼ばれる。
    private func finish(_ success: Bool) {
        guard verdict == nil else { return }
        verdict = success

        // 少し見せてから自動で戻る。届かなくてもボタンで戻れる。
        // このあと抽選と前進の演出が続くので、ここは短く切り上げる。
        Task {
            try? await Task.sleep(for: .seconds(success ? 0.8 : 1.2))
            close(success: success)
        }
    }

    /// 成功・失敗のどちらも必ずここを通して閉じる。
    private func close(success: Bool) {
        guard !hasClosed else { return }
        hasClosed = true
        onFinish(success)
    }
}
