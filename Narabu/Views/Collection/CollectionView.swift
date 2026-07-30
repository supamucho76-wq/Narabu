import SwiftUI

/// 受け取った景品の図鑑。全部そろえても何も起きない。
struct CollectionView: View {
    @Environment(QueueStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Prize?

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 12)]

    /// 一度でも受け取った景品の識別子。
    private var ownedIDs: Set<String> {
        Set(store.state.collected.map(\.prizeID))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                summary

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(PrizeCatalog.all) { prize in
                        let isOwned = ownedIDs.contains(prize.id)
                        PrizeCell(prize: prize, isOwned: isOwned)
                            .onTapGesture { if isOwned { selected = prize } }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(AppTheme.paper.ignoresSafeArea())
            .navigationTitle("景品図鑑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .sheet(item: $selected) { prize in
                PrizeDetailView(prize: prize, records: records(for: prize))
                    .presentationDetents([.medium])
            }
        }
        .tint(AppTheme.ink)
    }

    private var summary: some View {
        VStack(spacing: 4) {
            Text("\(ownedIDs.count) / \(PrizeCatalog.all.count)")
                .font(.system(size: 40, weight: .light, design: .rounded))
                .monospacedDigit()
            Text("すべて集めても、特に何も起きません。")
                .font(.caption2)
                .foregroundStyle(AppTheme.inkSecondary)
        }
        .padding(.vertical, 20)
    }

    private func records(for prize: Prize) -> [CollectedPrize] {
        store.state.collected
            .filter { $0.prizeID == prize.id }
            .sorted { $0.ticketNumber > $1.ticketNumber }
    }
}

private struct PrizeCell: View {
    let prize: Prize
    let isOwned: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(isOwned ? prize.name : "？")
                .font(.caption.weight(isOwned ? .medium : .regular))
                .foregroundStyle(isOwned ? AppTheme.ink : AppTheme.inkSecondary.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.8)

            if isOwned {
                Text(prize.rarity.label)
                    .font(.system(size: 9))
                    .foregroundStyle(AppTheme.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 88)
        .padding(8)
        .background(isOwned ? AppTheme.paper : AppTheme.ink.opacity(0.04))
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(AppTheme.ink.opacity(isOwned ? 0.25 : 0.1), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

private struct PrizeDetailView: View {
    let prize: Prize
    let records: [CollectedPrize]

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                PlacardLabel(text: prize.rarity.label)
                Text(prize.name)
                    .font(.title2.weight(.medium))
                    .multilineTextAlignment(.center)
                Text(prize.note)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.inkSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 28)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                PlacardLabel(text: "受け取った記録")
                ForEach(records) { record in
                    HStack {
                        Text("第\(String(format: "%04d", record.ticketNumber))号")
                            .foregroundStyle(AppTheme.stamp)
                        Text("\(record.lap)周目・\(record.daysWaited)日・\(record.weather.label)")
                            .foregroundStyle(AppTheme.inkSecondary)
                        Spacer()
                    }
                    .font(.caption.monospacedDigit())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
        .padding(.horizontal, 28)
        .background(AppTheme.paper.ignoresSafeArea())
        .foregroundStyle(AppTheme.ink)
    }
}
