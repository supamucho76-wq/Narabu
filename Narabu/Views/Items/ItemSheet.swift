import SwiftUI

/// 所持しているごぼう抜きアイテムの一覧。下から開く。
struct ItemSheet: View {
    @Environment(QueueStore.self) private var store
    @Environment(PurchaseStore.self) private var purchases
    @Environment(SoundPlayer.self) private var sound
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isVoiceEnabled") private var isVoiceEnabled = false

    /// 使うアイテムを親に渡す。演出は行列の画面で行う。
    let onUse: (GachaItem) -> Void
    /// 課金して追い抜く。
    let onPurchase: () -> Void

    var body: some View {
        NavigationStack {
            list
            .navigationTitle("アイテム")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 10) {
                if store.ownedItems.isEmpty {
                    ContentUnavailableView {
                        Label("アイテムがありません", systemImage: "shippingbox")
                    } description: {
                        Text("無料ガチャを引くと、列をごぼう抜きできる乗り物が手に入ります。")
                    }
                    .frame(minHeight: 220)
                } else {
                    ForEach(store.ownedItems, id: \.item.id) { owned in
                        card(owned.item, count: owned.count)
                    }
                }

                purchaseCard
                soundSettings

                #if DEBUG
                debugSection
                #endif
            }
            .padding(16)
        }
    }

    /// ガチャを待たずに進みたい人向け。演出は車と同じ。
    private var purchaseCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.stamp.opacity(0.14))
                Image(systemName: "car.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(AppTheme.stamp)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 3) {
                Text("タクシーを呼ぶ")
                    .font(.subheadline.weight(.semibold))
                Text("\(PurchaseStore.skipAmount)人抜き")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("ガチャを待たずに進めます")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                onPurchase()
                dismiss()
            } label: {
                if purchases.isPurchasing {
                    ProgressView()
                } else {
                    Text(purchases.priceLabel)
                }
            }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(AppTheme.ink)
            .clipShape(Capsule())
            .disabled(purchases.isPurchasing)
        }
        .padding(12)
        .background(AppTheme.paper)
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(AppTheme.ink.opacity(0.12), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func card(_ item: GachaItem, count: Int) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(item.rarity.color.opacity(0.16))
                Image(systemName: item.symbolName)
                    .font(.system(size: 24))
                    .foregroundStyle(item.rarity.color)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.rarity.label)
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(item.rarity.color)
                    Text(item.name)
                        .font(.subheadline.weight(.semibold))
                }
                Text(item.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("所持 \(count)個")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("使う") {
                onUse(item)
                dismiss()
            }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(count > 0 ? AppTheme.stamp : Color.secondary)
            .clipShape(Capsule())
            .disabled(count <= 0)
        }
        .padding(12)
        .background(AppTheme.paper)
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(AppTheme.ink.opacity(0.12), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// 音と、試している機能の入り切り。
    private var soundSettings: some View {
        @Bindable var sound = sound

        return VStack(alignment: .leading, spacing: 6) {
            Toggle("効果音", isOn: $sound.isEffectEnabled)
            Toggle("BGM", isOn: $sound.isMusicEnabled)

            Divider().padding(.vertical, 2)

            Toggle("声で通す（試験中）", isOn: $isVoiceEnabled)
            Text("実際に声を出して列を進めます。端末によっては不安定なため、既定では切ってあります。切っていても「押し通す」で同じように遊べます。")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.subheadline)
        .foregroundStyle(AppTheme.ink)
        .tint(AppTheme.stamp)
        .padding(12)
        .background(AppTheme.paper)
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(AppTheme.ink.opacity(0.12), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.top, 6)
    }

    #if DEBUG
    /// 開発中に初回ガチャを何度も確認するための操作。
    private var debugSection: some View {
        VStack(spacing: 8) {
            Divider().padding(.vertical, 8)
            Text("開発用")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Button("最初からやり直す（初回ガチャも戻る）") {
                store.resetForDebugging()
                dismiss()
            }
            .font(.caption)
            .foregroundStyle(.red)
        }
    }
    #endif
}
