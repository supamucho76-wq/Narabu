import Foundation

/// 列に並んでいる場所の天気。並ぶ以外にすることがないので、天気だけが出来事になる。
enum QueueWeather: String, Codable, CaseIterable {
    case clear
    case cloudy
    case rain
    case storm
    case snow
    case fog

    var label: String {
        switch self {
        case .clear: "晴れ"
        case .cloudy: "くもり"
        case .rain: "雨"
        case .storm: "暴風雨"
        case .snow: "雪"
        case .fog: "霧"
        }
    }

    /// その日の天気は日付だけで決まる。誰の列でも同じ空が広がっている。
    static func onDay(of date: Date) -> QueueWeather {
        let day = Int(floor(date.timeIntervalSince1970 / 86_400))
        let roll = QueueEngine.unitRandom(day, salt: 0xC10D)

        return switch roll {
        case ..<0.42: .clear
        case ..<0.68: .cloudy
        case ..<0.84: .rain
        case ..<0.90: .fog
        case ..<0.96: .snow
        default: .storm
        }
    }
}
