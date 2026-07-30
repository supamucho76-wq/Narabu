import SwiftUI

/// 何週間も並んだ末の、受け取りの瞬間。
/// 大げさな演出はせず、窓口の事務手続きとして淡々と渡す。
struct PrizeRevealView: View {
    let record: CollectedPrize

    @Environment(\.dismiss) private var dismiss
    @State private var hasAppeared = false

    private var prize: Prize? { PrizeCatalog.prize(for: record.prizeID) }

    var body: some View {
        ZStack {
            AppTheme.sky(tone: 0.34).ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                ticket

                VStack(spacing: 10) {
                    PlacardLabel(text: "受け取ったもの")
                    Text(prize?.name ?? "不明な品")
                        .font(.title.weight(.medium))
                        .multilineTextAlignment(.center)
                    if let note = prize?.note {
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.inkSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .opacity(hasAppeared ? 1 : 0)
                .animation(.easeIn(duration: 0.8).delay(0.6), value: hasAppeared)

                Spacer()

                VStack(spacing: 6) {
                    Text("\(record.daysWaited)日並びました。")
                    Text("列の最後尾にお戻りください。")
                }
                .font(.caption)
                .foregroundStyle(AppTheme.inkSecondary)

                Button("最後尾に戻る") { dismiss() }
                    .buttonStyle(QuietButtonStyle(emphasized: true))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .foregroundStyle(AppTheme.ink)
        .onAppear { hasAppeared = true }
    }

    /// 受け取った唯一の証明。通し番号だけが本物。
    private var ticket: some View {
        VStack(spacing: 12) {
            PlacardLabel(text: "整理券")

            Text("第 \(String(format: "%04d", record.ticketNumber)) 号")
                .font(.system(size: 34, weight: .medium, design: .serif))
                .foregroundStyle(AppTheme.stamp)

            Divider().overlay(AppTheme.ink.opacity(0.2))

            HStack(spacing: 18) {
                ticketField(label: "周回", value: "\(record.lap)周目")
                ticketField(label: "天候", value: record.weather.label)
                ticketField(label: "等級", value: prize?.rarity.label ?? "—")
            }
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 26)
        .background(AppTheme.paper)
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(AppTheme.ink.opacity(0.25), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .scaleEffect(hasAppeared ? 1 : 0.94)
        .opacity(hasAppeared ? 1 : 0)
        .animation(.snappy(duration: 0.7), value: hasAppeared)
    }

    private func ticketField(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(AppTheme.inkSecondary)
            Text(value)
                .font(.caption.weight(.medium))
        }
    }
}
