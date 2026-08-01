import SwiftUI

/// ミニゲームで使い回す部品。
///
/// どのゲームも「残り時間が減る」「進み具合が伸びる」の2つで出来ているので、
/// そこだけ共通にして、遊びかたの違いに集中できるようにする。
/// 中身はすべて画面を組み立てる関数で、呼ぶのはミニゲームの `body` の中だけ。
/// SwiftUI の View と同じ場所にいると宣言しておかないと、
/// ここで作った部品にクロージャを渡すたびに Swift 6 が競合を疑う。
@MainActor
enum MissionParts {
    /// 進み具合の帯。
    static func track(ratio: Double, tint: Color = AppTheme.stamp, height: Double = 8) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(AppTheme.ink.opacity(0.10))
                Capsule()
                    .fill(tint)
                    .frame(width: geometry.size.width * min(1, max(0, ratio)))
            }
        }
        .frame(height: height)
    }

    /// 残り時間。0になった瞬間に一度だけ知らせる。
    ///
    /// 締め切りの時刻ではなく秒数を渡す。時刻を外から渡す作りだと、
    /// 呼ぶ側が入れ忘れた一瞬に「もう時間切れ」と判定されてしまうため。
    static func countdown(
        seconds: Double,
        onExpire: @escaping () -> Void
    ) -> some View {
        Countdown(seconds: seconds, onExpire: onExpire)
    }

    /// 大きな数字。いま何回ぶんかを見せる。
    static func counter(_ value: Int, of total: Int) -> some View {
        Text("\(value) / \(total)")
            .font(.system(size: 30, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(AppTheme.ink)
    }

    /// 押しごたえのある大きなボタン。
    static func bigButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(AppTheme.stamp)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(GameButtonStyle())
    }

    /// 残り時間の表示。
    ///
    /// `enum` の中の関数から `.task` を使うと、閉じ込めた `onExpire` が
    /// どのアクターのものか決まらず Swift 6 に弾かれる。
    /// View にしておけば本体が `@MainActor` になるので、その心配がなくなる。
    ///
    /// **時計はこの View が自分で持つ。** 外から締め切りの時刻を受け取る作りだと、
    /// 呼ぶ側が入れるまでの一瞬が時間切れ扱いになり、開いた瞬間に失敗する。
    struct Countdown: View {
        let seconds: Double
        let onExpire: () -> Void

        /// 数え始めた時刻。画面に出た瞬間に入れ直す。
        @State private var startedAt = Date()
        /// 0秒になっても知らせるのは一度だけ。
        @State private var hasExpired = false

        var body: some View {
            TimelineView(.periodic(from: .now, by: 0.1)) { timeline in
                let elapsed = timeline.date.timeIntervalSince(startedAt)
                let remaining = max(0, max(0.5, seconds) - elapsed)

                Text(String(format: "残り %.1f秒", remaining))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AppTheme.inkSecondary)
                    .onChange(of: remaining <= 0) { _, expired in
                        guard expired, !hasExpired else { return }
                        hasExpired = true
                        onExpire()
                    }
            }
            .onAppear { startedAt = Date() }
        }
    }

    /// 遊ぶ場所の枠。どのゲームも同じ大きさの舞台で遊ぶ。
    static func stage<Content: View>(
        height: Double = 150,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(AppTheme.ink.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// スワイプの向き。
enum SwipeDirection: CaseIterable {
    case left
    case right
    case up

    var symbolName: String {
        switch self {
        case .left: "arrow.left"
        case .right: "arrow.right"
        case .up: "arrow.up"
        }
    }

    var label: String {
        switch self {
        case .left: "左へ"
        case .right: "右へ"
        case .up: "上へ"
        }
    }

    /// 指の動きから向きを読み取る。小さすぎる動きは無視する。
    static func of(_ translation: CGSize, threshold: Double = 28) -> SwipeDirection? {
        if abs(translation.width) > abs(translation.height) {
            guard abs(translation.width) > threshold else { return nil }
            return translation.width < 0 ? .left : .right
        }
        guard -translation.height > threshold else { return nil }
        return .up
    }
}
