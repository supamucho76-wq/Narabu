import SwiftUI

/// 装備の付け替えと、スキルの育成。
struct LoadoutView: View {
    @Environment(QueueStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var tab = Tab.equipment

    private enum Tab: String, CaseIterable, Identifiable {
        case equipment
        case skill

        var id: String { rawValue }
        var label: String {
            switch self {
            case .equipment: "装備"
            case .skill: "スキル"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    ForEach(Tab.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)

                ScrollView {
                    switch tab {
                    case .equipment: equipmentSection
                    case .skill: skillSection
                    }
                }
            }
            .background(AppTheme.paper.ignoresSafeArea())
            .navigationTitle("装備とスキル")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { coinBadge }
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .tint(AppTheme.ink)
    }

    private var coinBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "circle.hexagongrid.fill")
            Text(store.state.coins.formatted())
                .monospacedDigit()
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color(red: 0.72, green: 0.54, blue: 0.14))
    }

    // MARK: - 装備

    private var equipmentSection: some View {
        VStack(spacing: 18) {
            ForEach(EquipmentSlot.allCases) { slot in
                VStack(alignment: .leading, spacing: 8) {
                    Text(slot.label)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)

                    let owned = store.ownedEquipment(in: slot)
                    if owned.isEmpty {
                        Text("まだ手に入れていません")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 14)
                    } else {
                        ForEach(owned) { equipment in
                            equipmentRow(equipment, slot: slot)
                        }
                    }
                }
            }

            summary
        }
        .padding(16)
    }

    private func equipmentRow(_ equipment: Equipment, slot: EquipmentSlot) -> some View {
        let isEquipped = store.equippedItem(in: slot)?.id == equipment.id

        return Button {
            if isEquipped {
                store.unequip(slot)
            } else {
                store.equip(equipment)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: equipment.symbolName)
                    .font(.system(size: 20))
                    .frame(width: 34)
                    .foregroundStyle(isEquipped ? AppTheme.stamp : AppTheme.ink)

                VStack(alignment: .leading, spacing: 2) {
                    Text(equipment.name)
                        .font(.subheadline.weight(.semibold))
                    Text(equipment.detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(isEquipped ? "装備中" : "装備する")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isEquipped ? .white : AppTheme.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isEquipped ? AppTheme.stamp : Color.clear)
                    .overlay {
                        Capsule().strokeBorder(AppTheme.ink.opacity(isEquipped ? 0 : 0.3), lineWidth: 1)
                    }
                    .clipShape(Capsule())
            }
            .foregroundStyle(AppTheme.ink)
            .padding(12)
            .background(.white)
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isEquipped ? AppTheme.stamp.opacity(0.5) : AppTheme.ink.opacity(0.12), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - スキル

    private var skillSection: some View {
        VStack(spacing: 12) {
            if store.learnedSkills.isEmpty {
                ContentUnavailableView {
                    Label("スキルがありません", systemImage: "sparkles")
                } description: {
                    Text("ステージをクリアすると覚えます。")
                }
                .frame(minHeight: 280)
            } else {
                ForEach(store.learnedSkills, id: \.skill.id) { learned in
                    skillRow(learned.skill, level: learned.level)
                }
            }

            summary
        }
        .padding(16)
    }

    private func skillRow(_ skill: Skill, level: Int) -> some View {
        let isMax = level >= Skill.maxLevel
        let cost = Skill.upgradeCost(currentLevel: level)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: skill.symbolName)
                    .font(.system(size: 20))
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(skill.name)
                        .font(.subheadline.weight(.semibold))
                    Text(skill.detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("Lv.\(level)")
                    .font(.caption.weight(.bold).monospacedDigit())
            }

            HStack(spacing: 4) {
                ForEach(1...Skill.maxLevel, id: \.self) { step in
                    Capsule()
                        .fill(step <= level ? AppTheme.stamp : AppTheme.ink.opacity(0.12))
                        .frame(height: 4)
                }
            }

            Button {
                store.upgrade(skill)
            } label: {
                Text(isMax ? "最大まで育てました" : "強化する　\(cost.formatted())コイン")
                    .font(.caption.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.ink)
            .disabled(isMax || !store.canUpgrade(skill))
        }
        .foregroundStyle(AppTheme.ink)
        .padding(12)
        .background(.white)
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(AppTheme.ink.opacity(0.12), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - 今の効果

    private var summary: some View {
        let effects = store.effects

        return VStack(alignment: .leading, spacing: 6) {
            Text("いまの効果")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            effectRow("抜ける人数", value: "×\(effects.overtakeMultiplier.formatted(.number.precision(.fractionLength(0...2))))")
            effectRow("ガチャの待ち時間", value: "×\(effects.gachaCooldownMultiplier.formatted(.number.precision(.fractionLength(0...2))))")
            effectRow("前の人が抜ける確率", value: "+\(effects.eventSuccessBonus.formatted(.percent.precision(.fractionLength(0...1))))")
            effectRow("高レアの出やすさ", value: "+\(effects.gachaLuckBonus.formatted(.percent.precision(.fractionLength(0))))")
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.ink.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func effectRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).monospacedDigit()
        }
        .font(.caption2)
        .foregroundStyle(AppTheme.ink.opacity(0.75))
    }
}
