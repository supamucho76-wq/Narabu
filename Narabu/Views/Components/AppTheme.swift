import SwiftUI

/// 役所の番号札のような、そっけない見た目でそろえる。
/// 無意味なことを大真面目にやっている雰囲気を、色数の少なさで出す。
enum AppTheme {
    static let ink = Color(red: 0.13, green: 0.13, blue: 0.14)
    static let inkSecondary = Color(red: 0.42, green: 0.42, blue: 0.45)
    static let paper = Color(red: 0.96, green: 0.95, blue: 0.93)
    /// 整理券の判子の色。このアプリで唯一の鮮やかな色。
    static let stamp = Color(red: 0.72, green: 0.18, blue: 0.16)

    /// 景色の暗さを空の色に反映する。屋根の下に入るほど沈む。
    static func sky(tone: Double) -> Color {
        Color(
            red: 0.96 * tone + 0.10 * (1 - tone),
            green: 0.95 * tone + 0.11 * (1 - tone),
            blue: 0.93 * tone + 0.13 * (1 - tone)
        )
    }
}

/// 窓口の掲示のような、細い枠の見出し。
struct PlacardLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .tracking(2)
            .foregroundStyle(AppTheme.inkSecondary)
    }
}

struct QuietButtonStyle: ButtonStyle {
    var emphasized = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(emphasized ? AppTheme.paper : AppTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(emphasized ? AppTheme.ink : Color.clear)
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(AppTheme.ink.opacity(emphasized ? 0 : 0.3), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
