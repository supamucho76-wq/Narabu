import Foundation

/// 声の大きさ。強く言うほど効くが、目立つ。
enum VoiceVolume: Sendable {
    case quiet
    case normal
    case loud
    case tooLoud

    var label: String {
        switch self {
        case .quiet: "小声"
        case .normal: "普通の声"
        case .loud: "大声"
        case .tooLoud: "叫び声"
        }
    }

    /// 音の強さから決める。
    static func of(_ level: Double) -> VoiceVolume {
        switch level {
        case ..<0.16: .quiet
        case ..<0.45: .normal
        case ..<0.78: .loud
        default: .tooLoud
        }
    }
}

/// 声を出して前の人たちを動かす言葉。
enum VoicePhrase: String, CaseIterable, Sendable {
    case oi
    case doke
    case tooshite
    case isoide
    case sumimasen
    case onegai
    case jama
    case maeni

    /// 画面に出す代表的な言いかた。
    var label: String {
        switch self {
        case .oi: "おい！"
        case .doke: "どけ！"
        case .tooshite: "通して！"
        case .isoide: "急いでます！"
        case .sumimasen: "すみません！"
        case .onegai: "お願いします！"
        case .jama: "邪魔！"
        case .maeni: "前に行かせて！"
        }
    }

    /// 聞き取った文にこれが含まれていれば、その言葉だと判定する。
    var keywords: [String] {
        switch self {
        case .oi: ["おい", "オイ", "こら", "コラ"]
        case .doke: ["どけ", "ドケ", "どいて", "退いて", "どいで"]
        case .tooshite: ["通して", "とおして", "通してください"]
        case .isoide: ["急いで", "いそいで", "急いでます", "時間がない"]
        case .sumimasen: ["すみません", "すいません", "ごめんなさい", "失礼"]
        case .onegai: ["お願い", "おねがい", "頼み", "たのみ"]
        case .jama: ["邪魔", "じゃま"]
        case .maeni: ["前に行かせて", "前に", "先に行かせて", "先に"]
        }
    }

    /// 乱暴な言いかたか。警戒度が上がる。
    var isRough: Bool {
        switch self {
        case .oi, .doke, .jama: true
        case .tooshite, .isoide, .sumimasen, .onegai, .maeni: false
        }
    }

    /// うまくいったときに抜ける人数の幅。
    var advanceRange: ClosedRange<Int> {
        switch self {
        case .oi: 3...10
        case .doke: 5...15
        case .jama: 4...12
        case .tooshite: 2...8
        case .isoide: 5...12
        case .sumimasen: 1...5
        case .onegai: 2...6
        case .maeni: 3...9
        }
    }

    /// 基本の成功率。
    var baseChance: Double {
        switch self {
        case .sumimasen: 0.9
        case .onegai: 0.85
        case .oi: 0.75
        case .tooshite: 0.72
        case .isoide: 0.68
        case .maeni: 0.66
        case .doke: 0.6
        case .jama: 0.55
        }
    }

    /// 失敗したときに後ろへ下がるか。
    var failureCostsGround: Bool { isRough }

    /// 一度で上がる警戒度。
    var alertCost: Double {
        switch self {
        case .doke, .jama: 14
        case .oi: 10
        case .maeni: 5
        case .isoide, .tooshite: 3
        case .sumimasen, .onegai: -6
        }
    }

    /// この言葉に合う声の大きさ。合っていると成功しやすい。
    var preferredVolume: VoiceVolume {
        switch self {
        case .oi, .doke, .jama: .loud
        case .sumimasen, .onegai: .quiet
        default: .normal
        }
    }

    /// 聞き取った文から、どの言葉かを探す。
    ///
    /// 長い言いかたから先に見るので、「前に行かせて」が「前に」に負けない。
    static func match(in transcript: String) -> VoicePhrase? {
        let text = transcript.replacingOccurrences(of: " ", with: "")
        guard !text.isEmpty else { return nil }

        let candidates = allCases.flatMap { phrase in
            phrase.keywords.map { (phrase: phrase, keyword: $0) }
        }
        .sorted { $0.keyword.count > $1.keyword.count }

        return candidates.first { text.contains($0.keyword) }?.phrase
    }
}
