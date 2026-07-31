import SwiftUI

/// 受け取った記念品の図鑑。全部そろえても何も起きない。
struct CollectionView: View {
    @Environment(QueueStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Prize?
    @State private var filter: PrizeRarity?

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 10)]

    private var ownedIDs: Set<String> { store.collectedPrizeIDs }

    private var shown: [Prize] {
        guard let filter else { return PrizeCatalog.all }
        return PrizeCatalog.all.filter { $0.rarity == filter }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                summary
                filterBar

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(shown) { prize in
                        let isOwned = ownedIDs.contains(prize.id)
                        PrizeCell(prize: prize, isOwned: isOwned)
                            .onTapGesture { if isOwned { selected = prize } }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(AppTheme.paper.ignoresSafeArea())
            .navigationTitle("記念品図鑑")
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
                .font(.system(size: 38, weight: .light, design: .rounded))
                .monospacedDigit()
            Text("すべて集めても、特に何も起きません。")
                .font(.caption2)
                .foregroundStyle(AppTheme.inkSecondary)
        }
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                filterChip(title: "すべて", rarity: nil)
                ForEach(PrizeRarity.allCases, id: \.self) { rarity in
                    filterChip(title: rarity.label, rarity: rarity)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 12)
    }

    private func filterChip(title: String, rarity: PrizeRarity?) -> some View {
        let isActive = filter == rarity

        return Button {
            filter = rarity
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isActive ? .white : AppTheme.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isActive ? (rarity?.color ?? AppTheme.ink) : Color.clear)
                .overlay {
                    Capsule().strokeBorder(AppTheme.ink.opacity(isActive ? 0 : 0.25), lineWidth: 1)
                }
                .clipShape(Capsule())
        }
    }

    private func records(for prize: Prize) -> [CollectedPrize] {
        store.state.collected
            .filter { $0.prizeID == prize.id }
            .sorted { $0.ticketNumber > $1.ticketNumber }
    }
}

/// 未獲得はシルエットだけ見せる。何が残っているかは分かるが、中身は分からない。
private struct PrizeCell: View {
    let prize: Prize
    let isOwned: Bool

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: isOwned ? "shippingbox.fill" : "questionmark")
                .font(.system(size: 20))
                .foregroundStyle(isOwned ? prize.rarity.color : AppTheme.ink.opacity(0.18))

            Text(isOwned ? prize.name : "？？？")
                .font(.system(size: 11, weight: isOwned ? .semibold : .regular))
                .foregroundStyle(isOwned ? AppTheme.ink : AppTheme.ink.opacity(0.3))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.75)

            Text(prize.rarity.label)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(isOwned ? prize.rarity.color : AppTheme.inkSecondary)

            if isOwned, prize.hiddenEffect != nil {
                Image(systemName: "sparkles")
                    .font(.system(size: 9))
                    .foregroundStyle(Color(red: 0.92, green: 0.72, blue: 0.24))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 104)
        .padding(8)
        .background(isOwned ? prize.rarity.color.opacity(0.07) : AppTheme.ink.opacity(0.03))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    isOwned ? prize.rarity.color.opacity(0.55) : AppTheme.ink.opacity(0.1),
                    lineWidth: isOwned ? 1.5 : 1
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct PrizeDetailView: View {
    let prize: Prize
    let records: [CollectedPrize]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(prize.rarity.color)

                    Text(prize.rarity.label)
                        .font(.system(size: 11, weight: .black))
                        .tracking(2)
                        .foregroundStyle(prize.rarity.color)

                    Text(prize.name)
                        .font(.title3.weight(.bold))
                        .multilineTextAlignment(.center)

                    Text(prize.note)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.inkSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 24)

                if let effect = prize.hiddenEffectLabel {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text(effect)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color(red: 0.72, green: 0.54, blue: 0.14))
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 0.98, green: 0.94, blue: 0.80))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("受け取った記録")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.inkSecondary)

                    ForEach(records) { record in
                        HStack(spacing: 8) {
                            Text("第\(String(format: "%04d", record.ticketNumber))号")
                                .foregroundStyle(AppTheme.stamp)
                            Text("STAGE \(record.stageNumber)")
                            Text("\(record.minutesWaited)分並んだ")
                                .foregroundStyle(AppTheme.inkSecondary)
                            Spacer()
                        }
                        .font(.caption.monospacedDigit())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(AppTheme.paper.ignoresSafeArea())
        .foregroundStyle(AppTheme.ink)
    }
}
