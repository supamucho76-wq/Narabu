import SwiftUI

/// 装備の付け替えと、スキルの育成。
///
/// 数字だけ並べても効果が分からないので、
/// 「実際に何人多く進めるか」「今と次でどう変わるか」を必ず添える。
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
                    HStack {
                        Text(slot.label)
                            .font(.caption.weight(.bold))
                        Spacer()
                        Text(store.equippedItem(in: slot)?.name ?? "なし")
                            .font(.caption2)
                    }
                    .foregroundStyle(AppTheme.inkSecondary)

                    ForEach(EquipmentCatalog.items(in: slot)) { equipment in
                        equipmentRow(equipment, slot: slot)
                    }
                }
            }

            summary
        }
        .padding(16)
    }

    private func equipmentRow(_ equipment: Equipment, slot: EquipmentSlot) -> some View {
        let isOwned = store.state.ownedEquipment.contains(equipment.id)
        let isEquipped = store.equippedItem(in: slot)?.id == equipment.id

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(equipment.rarity.color.opacity(isOwned ? 0.16 : 0.06))
                    Image(systemName: isOwned ? equipment.symbolName : "lock.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(isOwned ? equipment.rarity.color : AppTheme.inkSecondary)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(equipment.rarity.label)
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(equipment.rarity.color)
                        Text(equipment.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isOwned ? AppTheme.ink : AppTheme.inkSecondary)
                    }
                    Text(isOwned ? equipment.detail : "未入手：\(equipment.source)")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            if isOwned, let example = equipment.concreteExample {
                Text(example)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.stamp)
            }

            // 付け替えると何が変わるかを、その場で見せる。
            if isOwned, !isEquipped, let change = comparison(equipping: equipment, in: slot) {
                Text(change)
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.inkSecondary)
            }

            if isOwned {
                HStack(spacing: 8) {
                    Button {
                        if isEquipped {
                            store.unequip(slot)
                        } else {
                            store.equip(equipment)
                        }
                    } label: {
                        Text(isEquipped ? "外す" : "装備する")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(isEquipped ? AppTheme.ink : .white)
                            .frame(maxWidth: .infinity, minHeight: AppTheme.minimumTapHeight)
                            .background(isEquipped ? Color.clear : AppTheme.stamp)
                            .overlay {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(AppTheme.ink.opacity(isEquipped ? 0.3 : 0), lineWidth: 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(GameButtonStyle())

                    if isEquipped {
                        Text("装備中")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.stamp)
                    }
                }
            }
        }
        .padding(12)
        .background(.white)
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    isEquipped ? equipment.rarity.color.opacity(0.6) : AppTheme.ink.opacity(0.1),
                    lineWidth: isEquipped ? 2 : 1
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .opacity(isOwned ? 1 : 0.65)
    }

    /// 今つけているものと比べて、どう変わるか。
    private func comparison(equipping equipment: Equipment, in slot: EquipmentSlot) -> String? {
        let current = store.equippedItem(in: slot)?.effects ?? .none
        let next = equipment.effects

        if next.overtakeMultiplier != current.overtakeMultiplier {
            return "抜ける人数：×\(fmt(current.overtakeMultiplier)) → ×\(fmt(next.overtakeMultiplier))"
        }
        if next.eventSuccessBonus != current.eventSuccessBonus {
            return "譲ってもらえる確率：+\(pct(current.eventSuccessBonus)) → +\(pct(next.eventSuccessBonus))"
        }
        if next.gachaCooldownMultiplier != current.gachaCooldownMultiplier {
            return "ガチャの待ち時間：×\(fmt(current.gachaCooldownMultiplier)) → ×\(fmt(next.gachaCooldownMultiplier))"
        }
        if next.gachaLuckBonus != current.gachaLuckBonus {
            return "高レアの出やすさ：+\(pct(current.gachaLuckBonus)) → +\(pct(next.gachaLuckBonus))"
        }
        return nil
    }

    // MARK: - スキル

    private var skillSection: some View {
        VStack(spacing: 12) {
            ForEach(SkillCatalog.all) { skill in
                skillRow(skill, level: store.state.skillLevels[skill.id] ?? 0)
            }
            summary
        }
        .padding(16)
    }

    private func skillRow(_ skill: Skill, level: Int) -> some View {
        let isLearned = level > 0
        let isMax = level >= Skill.maxLevel
        let cost = Skill.upgradeCost(currentLevel: max(1, level))
        let canAfford = store.state.coins >= cost

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: isLearned ? skill.symbolName : "lock.fill")
                    .font(.system(size: 18))
                    .frame(width: 32)
                    .foregroundStyle(isLearned ? AppTheme.ink : AppTheme.inkSecondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(skill.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isLearned ? AppTheme.ink : AppTheme.inkSecondary)
                    Text(skill.detail)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.inkSecondary)
                }

                Spacer()

                Text(isLearned ? "Lv.\(level)" : "未習得")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(isLearned ? AppTheme.ink : AppTheme.inkSecondary)
            }

            if isLearned {
                HStack(spacing: 4) {
                    ForEach(1...Skill.maxLevel, id: \.self) { step in
                        Capsule()
                            .fill(step <= level ? AppTheme.stamp : AppTheme.ink.opacity(0.12))
                            .frame(height: 4)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("現在：\(skill.valueLabel(atLevel: level))")
                    if !isMax {
                        Text("Lv.\(level + 1)：\(skill.valueLabel(atLevel: level + 1))")
                            .foregroundStyle(AppTheme.stamp)
                    }
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppTheme.inkSecondary)

                Button {
                    store.upgrade(skill)
                } label: {
                    Text(upgradeLabel(isMax: isMax, canAfford: canAfford, cost: cost))
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.ink)
                .disabled(isMax || !canAfford)
            } else {
                Text("ステージをクリアすると覚えます")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.inkSecondary)
            }
        }
        .padding(12)
        .background(.white)
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(AppTheme.ink.opacity(0.1), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .opacity(isLearned ? 1 : 0.65)
    }

    /// 押せないときは、なぜ押せないかを書く。
    private func upgradeLabel(isMax: Bool, canAfford: Bool, cost: Int) -> String {
        if isMax { return "最大まで育てました" }
        if !canAfford { return "コインが足りません（\(cost.formatted())必要）" }
        return "強化する　\(cost.formatted())コイン"
    }

    // MARK: - 今の効果

    private var summary: some View {
        let effects = store.effects

        return VStack(alignment: .leading, spacing: 7) {
            Text("いまの合計")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.inkSecondary)

            effectRow("アイテムで抜ける人数",
                      value: "×\(fmt(effects.overtakeMultiplier))",
                      note: "車100人が\(Int((100 * effects.overtakeMultiplier).rounded()))人になる")
            effectRow("無料ガチャの待ち時間",
                      value: "×\(fmt(effects.gachaCooldownMultiplier))",
                      note: "60分が\(Int(60 * effects.gachaCooldownMultiplier))分になる")
            effectRow("相手が譲ってくれる確率",
                      value: "+\(pct(effects.eventSuccessBonus))",
                      note: "話しかけたときに成功しやすくなる")
            effectRow("高レアの出やすさ",
                      value: "+\(pct(effects.gachaLuckBonus))",
                      note: "電車や車が出る割合が増える")
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.ink.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func effectRow(_ title: String, value: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack {
                Text(title)
                Spacer()
                Text(value).monospacedDigit().fontWeight(.semibold)
            }
            .font(.caption2)
            Text(note)
                .font(.system(size: 9))
                .foregroundStyle(AppTheme.inkSecondary)
        }
        .foregroundStyle(AppTheme.ink.opacity(0.8))
    }

    private func fmt(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    private func pct(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0...1)))
    }
}
