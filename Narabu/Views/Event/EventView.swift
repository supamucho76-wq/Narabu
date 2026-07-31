import SwiftUI
import UIKit

/// 列の中で起きた出来事を見せて、選ばせる画面。
struct EventView: View {
    let event: QueueEvent
    let onChoose: (QueueEvent.Choice) -> Void

    @State private var chosen: QueueEvent.Choice?

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: event.symbolName)
                    .font(.system(size: 28))
                    .foregroundStyle(AppTheme.stamp)

                VStack(spacing: 6) {
                    Text(event.title)
                        .font(.headline)
                    Text(event.situation)
                        .font(.caption)
                        .foregroundStyle(AppTheme.inkSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let chosen {
                    outcome(chosen)
                } else {
                    choices
                }
            }
            .foregroundStyle(AppTheme.ink)
            .padding(22)
            .background(AppTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 24)
            .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
        }
    }

    private var choices: some View {
        VStack(spacing: 8) {
            ForEach(Array(event.choices.enumerated()), id: \.offset) { _, choice in
                Button {
                    chosen = choice
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()

                    Task {
                        try? await Task.sleep(for: .seconds(1.8))
                        onChoose(choice)
                    }
                } label: {
                    Text(choice.label)
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.ink)
            }
        }
    }

    private func outcome(_ choice: QueueEvent.Choice) -> some View {
        VStack(spacing: 10) {
            Text(choice.result)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                if choice.advance != 0 {
                    gain(
                        symbol: choice.advance > 0 ? "arrow.up.forward" : "arrow.down.backward",
                        text: choice.advance > 0 ? "\(choice.advance)人前進" : "\(-choice.advance)人後退",
                        tint: choice.advance > 0 ? AppTheme.stamp : AppTheme.inkSecondary
                    )
                }
                if choice.coins > 0 {
                    gain(symbol: "circle.hexagongrid.fill", text: "+\(choice.coins)",
                         tint: Color(red: 0.72, green: 0.54, blue: 0.14))
                }
                if let itemID = choice.itemID, let item = GachaCatalog.item(id: itemID) {
                    gain(symbol: item.symbolName, text: item.name, tint: item.rarity.color)
                }
            }
        }
    }

    private func gain(symbol: String, text: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
            Text(text)
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(tint)
    }
}
