import SwiftUI

/// ミニゲームで使い回す部品。
///
/// どのゲームも「残り時間が減る」「進み具合が伸びる」の2つで出来ているので、
/// そこだけ共通にして、遊びかたの違いに集中できるようにする。
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
    static func countdown(
        until deadline: Date,
        onExpire: @escaping () -> Void
    ) -> some View {
        Countdown(deadline: deadline, onExpire: onExpire)
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
    struct Countdown: View {
        let deadline: Date
        let onExpire: () -> Void

        /// 0秒になっても知らせるのは一度だけ。
        @State private var hasExpired = false

        var body: some View {
            TimelineView(.periodic(from: .now, by: 0.1)) { timeline in
                let remaining = max(0, deadline.timeIntervalSince(timeline.date))

                Text(String(format: "残り %.1f秒", remaining))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AppTheme.inkSecondary)
                    .onChange(of: remaining <= 0, initial: true) { _, expired in
                        guard expired, !hasExpired else { return }
                        hasExpired = true
                        onExpire()
                    }
            }
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
