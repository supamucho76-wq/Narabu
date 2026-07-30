import SwiftUI

/// 列に並んでいる人が、待ち時間に何をしているか。
enum QueueActivity: CaseIterable, Sendable {
    case standing
    case phone
    case sleeping
    case exercising
    case walkingDog
    case suitcase
    case reading
    case coffee
    case umbrella
    case music
    case stretching
    case shopping

    var label: String {
        switch self {
        case .standing: "じっと立っている"
        case .phone: "スマホを見ている"
        case .sleeping: "立ったまま寝ている"
        case .exercising: "筋トレしている"
        case .walkingDog: "犬を連れている"
        case .suitcase: "スーツケースを持った"
        case .reading: "本を読んでいる"
        case .coffee: "コーヒーを飲んでいる"
        case .umbrella: "傘を杖にしている"
        case .music: "音楽を聴いている"
        case .stretching: "ストレッチしている"
        case .shopping: "買い物袋を提げた"
        }
    }

    /// 腕を上げる高さ。0 は下ろしたまま。
    var armRaise: Double {
        switch self {
        case .phone, .reading, .coffee: 0.55
        case .exercising: 1.0
        case .stretching: 0.85
        case .music: 0.3
        default: 0
        }
    }
}

enum HairStyle: CaseIterable, Sendable {
    case short
    case long
    case bun
    case cap
    case beanie
    case bald
}

/// 列に並んでいる一人。並び順から決まるので、進んでも同じ人は同じ姿のまま。
struct QueuePerson: Equatable, Sendable {
    let persona: String
    let activity: QueueActivity
    let hairStyle: HairStyle
    let skin: Color
    let hair: Color
    let top: Color
    let bottom: Color
    let accent: Color
    /// 背の高さの個人差。
    let heightScale: Double
    /// 横幅の個人差。
    let build: Double
    /// 列の中の立ち位置の癖。まっすぐには並ばない。
    let lateralOffset: Double
    /// 揺れかたの位相。全員が同時に揺れないようにする。
    let swayPhase: Double

    var descriptor: String { activity.label + persona }
}

enum PersonFactory {
    private static let personas = [
        "小学生", "中学生", "高校生", "大学生", "サラリーマン", "OL",
        "主婦", "旅行者", "お年寄り", "配達員", "作業員", "観光客",
        "看護師", "ミュージシャン", "常連客", "近所の人", "会社員", "学生"
    ]

    private static let skinTones = [
        Color(red: 0.97, green: 0.85, blue: 0.75),
        Color(red: 0.93, green: 0.78, blue: 0.66),
        Color(red: 0.84, green: 0.66, blue: 0.52),
        Color(red: 0.68, green: 0.49, blue: 0.36),
        Color(red: 0.48, green: 0.34, blue: 0.26)
    ]

    private static let hairColors = [
        Color(red: 0.13, green: 0.11, blue: 0.10),
        Color(red: 0.24, green: 0.17, blue: 0.13),
        Color(red: 0.40, green: 0.28, blue: 0.18),
        Color(red: 0.62, green: 0.50, blue: 0.32),
        Color(red: 0.72, green: 0.72, blue: 0.74),
        Color(red: 0.55, green: 0.24, blue: 0.24)
    ]

    private static let topColors = [
        Color(red: 0.22, green: 0.30, blue: 0.45),
        Color(red: 0.72, green: 0.28, blue: 0.26),
        Color(red: 0.34, green: 0.44, blue: 0.34),
        Color(red: 0.90, green: 0.88, blue: 0.84),
        Color(red: 0.28, green: 0.28, blue: 0.30),
        Color(red: 0.82, green: 0.66, blue: 0.30),
        Color(red: 0.46, green: 0.36, blue: 0.52),
        Color(red: 0.86, green: 0.56, blue: 0.42),
        Color(red: 0.30, green: 0.54, blue: 0.58),
        Color(red: 0.64, green: 0.62, blue: 0.58)
    ]

    private static let bottomColors = [
        Color(red: 0.24, green: 0.26, blue: 0.32),
        Color(red: 0.18, green: 0.20, blue: 0.26),
        Color(red: 0.40, green: 0.36, blue: 0.32),
        Color(red: 0.30, green: 0.34, blue: 0.44),
        Color(red: 0.52, green: 0.48, blue: 0.44),
        Color(red: 0.22, green: 0.22, blue: 0.22)
    ]

    /// 列の何番目の人かを渡すと、その人の姿が決まる。
    static func person(atQueueIndex index: Int) -> QueuePerson {
        QueuePerson(
            persona: pick(personas, index, 0x11A3),
            activity: pick(QueueActivity.allCases, index, 0x22B4),
            hairStyle: pick(HairStyle.allCases, index, 0x33C5),
            skin: pick(skinTones, index, 0x44D6),
            hair: pick(hairColors, index, 0x55E7),
            top: pick(topColors, index, 0x66F8),
            bottom: pick(bottomColors, index, 0x7709),
            accent: pick(topColors, index, 0x881A),
            heightScale: 0.88 + random(index, 0x991B) * 0.24,
            build: 0.9 + random(index, 0xAA2C) * 0.26,
            lateralOffset: random(index, 0xBB3D) * 2 - 1,
            swayPhase: random(index, 0xCC4E) * 6.283
        )
    }

    /// プレイヤー自身。ほかの人と同じ列に、同じように立っている。
    static let player = QueuePerson(
        persona: "あなた",
        activity: .standing,
        hairStyle: .short,
        skin: Color(red: 0.95, green: 0.82, blue: 0.72),
        hair: Color(red: 0.15, green: 0.13, blue: 0.12),
        top: AppTheme.stamp,
        bottom: Color(red: 0.22, green: 0.24, blue: 0.30),
        accent: AppTheme.stamp,
        heightScale: 1.0,
        build: 1.0,
        lateralOffset: 0,
        swayPhase: 0
    )

    private static func random(_ index: Int, _ salt: UInt64) -> Double {
        QueueEngine.unitRandom(index, salt: salt)
    }

    private static func pick<T>(_ options: [T], _ index: Int, _ salt: UInt64) -> T {
        let i = Int(random(index, salt) * Double(options.count))
        return options[min(i, options.count - 1)]
    }
}
