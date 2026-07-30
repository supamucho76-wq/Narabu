import SwiftUI

/// 列に並んでいる者の種類。ラーメン屋の行列だが、並んでいるのは人間だけではない。
enum PersonType: CaseIterable, Sendable {
    case ordinary
    case suit
    case baby
    case samurai
    case alien
    case mascot
    case santa
    case maid
    case sumo
    case ghost
    case angel
    case astronaut

    var label: String {
        switch self {
        case .ordinary: ""
        case .suit: "スーツのおじさん"
        case .baby: "赤ちゃん"
        case .samurai: "武士"
        case .alien: "宇宙人"
        case .mascot: "着ぐるみ"
        case .santa: "サンタ"
        case .maid: "メイド"
        case .sumo: "相撲取り"
        case .ghost: "亡霊"
        case .angel: "天使"
        case .astronaut: "宇宙飛行士"
        }
    }

    /// 背の高さの倍率。
    var heightMultiplier: Double {
        switch self {
        case .baby: 0.55
        case .sumo: 1.12
        case .mascot: 1.08
        case .samurai: 1.04
        default: 1.0
        }
    }

    /// 横幅の倍率。
    var buildMultiplier: Double {
        switch self {
        case .sumo: 1.85
        case .mascot: 1.5
        case .baby: 1.25
        case .alien: 0.82
        default: 1.0
        }
    }

    /// その場所で見かけやすいか。景色が変わると並んでいる顔ぶれも変わる。
    func weight(in scene: SceneKind) -> Double {
        switch (self, scene) {
        case (.ordinary, _): 26
        case (.alien, .space): 14
        case (.astronaut, .space): 10
        case (.ghost, .hell), (.ghost, .heaven): 14
        case (.angel, .heaven): 16
        case (.santa, .snow): 10
        case (.samurai, .forest): 6
        case (.mascot, .park): 14
        case (.baby, .park): 8
        case (.maid, .night), (.mascot, .hall): 10
        case (.sumo, .ramen), (.sumo, .shopping): 5
        case (.alien, _), (.astronaut, _), (.ghost, _), (.angel, _): 0.4
        default: 2.2
        }
    }
}

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
    let type: PersonType
    let persona: String
    let activity: QueueActivity
    let hairStyle: HairStyle
    let skin: Color
    let hair: Color
    let top: Color
    let bottom: Color
    let accent: Color
    let heightScale: Double
    let build: Double
    /// 列の中の立ち位置の癖。まっすぐには並ばない。
    let lateralOffset: Double
    /// 揺れかたの位相。全員が同時に揺れないようにする。
    let swayPhase: Double
    /// 話しかけると漏らしてくる一言。
    let remark: String

    /// 「スマホを見ている宇宙人」
    var descriptor: String {
        type == .ordinary ? activity.label + persona : activity.label + type.label
    }
}

enum PersonFactory {
    private static let personas = [
        "小学生", "中学生", "高校生", "大学生", "サラリーマン", "OL",
        "主婦", "旅行者", "お年寄り", "配達員", "作業員", "観光客",
        "看護師", "ミュージシャン", "常連客", "近所の人", "会社員", "学生"
    ]

    /// 前の人が漏らしてくること。本当かどうかは分からない。
    private static let remarks = [
        "昨日から並んでます。",
        "これで景品5個目です。",
        "実は替え玉が目当てなんです。",
        "前の人、さっき入れ替わりました。",
        "この列、一回宇宙に出るらしいですよ。",
        "スープが売り切れたら解散だそうです。",
        "私、実は偽物です。",
        "3周目です。もう味は覚えました。",
        "並んでる理由、忘れちゃいました。",
        "券売機、故障してるって噂です。",
        "後ろの人とはさっき友達になりました。",
        "地獄のあたりが一番空いてますよ。",
        "店主、まだ生まれてないらしいです。",
        "去年もここに並んでました。",
        "隣の列のほうが早いって聞きました。",
        "私の順番、誰かに売りました。",
        "ラーメン、そんなに好きじゃないんです。",
        "天国を過ぎたら、あと少しです。",
        "この行列、地球3周してるそうです。",
        "抜かした人は帰ってこないらしいですよ。"
    ]

    private static let skinTones = [
        Color(red: 0.98, green: 0.86, blue: 0.76),
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
        Color(red: 0.22, green: 0.34, blue: 0.56),
        Color(red: 0.80, green: 0.26, blue: 0.24),
        Color(red: 0.30, green: 0.50, blue: 0.34),
        Color(red: 0.94, green: 0.92, blue: 0.88),
        Color(red: 0.26, green: 0.26, blue: 0.28),
        Color(red: 0.92, green: 0.70, blue: 0.24),
        Color(red: 0.48, green: 0.34, blue: 0.60),
        Color(red: 0.94, green: 0.56, blue: 0.38),
        Color(red: 0.24, green: 0.60, blue: 0.64),
        Color(red: 0.86, green: 0.46, blue: 0.62)
    ]

    private static let bottomColors = [
        Color(red: 0.24, green: 0.26, blue: 0.32),
        Color(red: 0.18, green: 0.20, blue: 0.26),
        Color(red: 0.42, green: 0.36, blue: 0.30),
        Color(red: 0.30, green: 0.34, blue: 0.44),
        Color(red: 0.56, green: 0.50, blue: 0.44),
        Color(red: 0.22, green: 0.22, blue: 0.22)
    ]

    /// 列の何番目の人かを渡すと、その人の姿が決まる。
    ///
    /// 立っている場所によって顔ぶれが変わる。宇宙では宇宙人が、天国では天使が増える。
    static func person(atQueueIndex index: Int, scene: SceneKind) -> QueuePerson {
        let type = pickType(index: index, scene: scene)

        return QueuePerson(
            type: type,
            persona: pick(personas, index, 0x11A3),
            activity: pick(QueueActivity.allCases, index, 0x22B4),
            hairStyle: pick(HairStyle.allCases, index, 0x33C5),
            skin: skin(for: type, index: index),
            hair: pick(hairColors, index, 0x55E7),
            top: top(for: type, index: index),
            bottom: bottom(for: type, index: index),
            accent: pick(topColors, index, 0x881A),
            heightScale: (0.9 + random(index, 0x991B) * 0.2) * type.heightMultiplier,
            build: (0.92 + random(index, 0xAA2C) * 0.2) * type.buildMultiplier,
            lateralOffset: random(index, 0xBB3D) * 2 - 1,
            swayPhase: random(index, 0xCC4E) * 6.283,
            remark: pick(remarks, index, 0xDD5F)
        )
    }

    /// プレイヤー自身。ほかの人と同じ列に、同じように立っている。
    static let player = QueuePerson(
        type: .ordinary,
        persona: "あなた",
        activity: .standing,
        hairStyle: .short,
        skin: Color(red: 0.96, green: 0.83, blue: 0.73),
        hair: Color(red: 0.14, green: 0.12, blue: 0.11),
        top: AppTheme.stamp,
        bottom: Color(red: 0.20, green: 0.22, blue: 0.30),
        accent: Color(red: 1.0, green: 0.86, blue: 0.34),
        heightScale: 1.04,
        build: 1.0,
        lateralOffset: 0,
        swayPhase: 0,
        remark: ""
    )

    // MARK: - 種類ごとの色

    private static func skin(for type: PersonType, index: Int) -> Color {
        switch type {
        case .alien: Color(red: 0.58, green: 0.82, blue: 0.52)
        case .ghost: Color(red: 0.82, green: 0.86, blue: 0.92)
        case .mascot: pick(topColors, index, 0x44D6)
        default: pick(skinTones, index, 0x44D6)
        }
    }

    private static func top(for type: PersonType, index: Int) -> Color {
        switch type {
        case .suit: Color(red: 0.20, green: 0.22, blue: 0.28)
        case .santa: Color(red: 0.78, green: 0.16, blue: 0.16)
        case .maid: Color(red: 0.16, green: 0.16, blue: 0.20)
        case .sumo: Color(red: 0.86, green: 0.70, blue: 0.58)
        case .samurai: Color(red: 0.24, green: 0.28, blue: 0.36)
        case .astronaut: Color(red: 0.92, green: 0.93, blue: 0.95)
        case .angel: Color(red: 0.98, green: 0.97, blue: 0.90)
        case .ghost: Color(red: 0.80, green: 0.84, blue: 0.92)
        case .baby: Color(red: 0.98, green: 0.86, blue: 0.62)
        case .alien: Color(red: 0.52, green: 0.76, blue: 0.48)
        case .mascot: pick(topColors, index, 0x66F8)
        case .ordinary: pick(topColors, index, 0x66F8)
        }
    }

    private static func bottom(for type: PersonType, index: Int) -> Color {
        switch type {
        case .suit: Color(red: 0.16, green: 0.18, blue: 0.24)
        case .santa: Color(red: 0.70, green: 0.14, blue: 0.14)
        case .maid: Color(red: 0.20, green: 0.20, blue: 0.24)
        case .sumo: Color(red: 0.30, green: 0.24, blue: 0.44)
        case .samurai: Color(red: 0.30, green: 0.32, blue: 0.40)
        case .astronaut: Color(red: 0.88, green: 0.89, blue: 0.92)
        case .angel, .ghost: Color(red: 0.90, green: 0.92, blue: 0.96)
        case .baby: Color(red: 0.96, green: 0.92, blue: 0.80)
        case .alien: Color(red: 0.46, green: 0.70, blue: 0.44)
        case .mascot: pick(topColors, index, 0x7709)
        case .ordinary: pick(bottomColors, index, 0x7709)
        }
    }

    // MARK: - 抽選

    /// 場所ごとの出やすさで種類を選ぶ。
    private static func pickType(index: Int, scene: SceneKind) -> PersonType {
        let weights = PersonType.allCases.map { $0.weight(in: scene) }
        let total = weights.reduce(0, +)
        var roll = random(index, 0xEE60) * total

        for (type, weight) in zip(PersonType.allCases, weights) {
            roll -= weight
            if roll <= 0 { return type }
        }
        return .ordinary
    }

    private static func random(_ index: Int, _ salt: UInt64) -> Double {
        QueueEngine.unitRandom(index, salt: salt)
    }

    private static func pick<T>(_ options: [T], _ index: Int, _ salt: UInt64) -> T {
        let i = Int(random(index, salt) * Double(options.count))
        return options[min(i, options.count - 1)]
    }
}
