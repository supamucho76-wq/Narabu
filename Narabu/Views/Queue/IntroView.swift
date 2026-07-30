import SwiftUI

/// 最初に一度だけ出る、なぜ並んでいるかの説明。
///
/// ここで「ただのラーメン屋」だと言い切っておくほど、
/// このあと列が宇宙や地獄を通ることが可笑しくなる。
struct IntroView: View {
    let onStart: () -> Void

    var body: some View {
        ZStack {
            Color(red: 0.12, green: 0.10, blue: 0.10).ignoresSafeArea()

            VStack(spacing: 26) {
                Spacer()

                VStack(spacing: 10) {
                    Text("世界一号店")
                        .font(.system(size: 15, weight: .semibold))
                        .tracking(6)
                        .foregroundStyle(Color(red: 0.94, green: 0.86, blue: 0.62))

                    Text("ラーメン")
                        .font(.system(size: 54, weight: .black))
                        .foregroundStyle(.white)

                    noren
                }

                VStack(spacing: 14) {
                    Text("開店しました。")
                    Text("現在 8,000人がお並びです。")
                        .font(.body.weight(.semibold))
                    Text("最後尾はこちらです。")
                }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)

                Spacer()

                Text("列がどこを通っているかについて、\n当店は関知しておりません。")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)

                Button(action: onStart) {
                    Text("最後尾に並ぶ")
                        .font(.headline)
                        .foregroundStyle(Color(red: 0.12, green: 0.10, blue: 0.10))
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(Color(red: 0.94, green: 0.86, blue: 0.62))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 28)
        }
    }

    /// 赤い暖簾。
    private var noren: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { _ in
                Rectangle()
                    .fill(Color(red: 0.74, green: 0.16, blue: 0.14))
                    .frame(width: 22, height: 34)
            }
        }
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 3, topTrailingRadius: 3))
        .padding(.top, 6)
    }
}
