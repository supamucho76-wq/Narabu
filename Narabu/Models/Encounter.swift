import Foundation

/// 駆け引きのときに選べる行動。
enum EncounterAction: String, CaseIterable, Identifiable, Sendable {
    case tapShoulder
    case talk
    case surprise
    case cheer
    case highFive
    case silentPressure

    var id: String { rawValue }

    var label: String {
        switch self {
        case .tapShoulder: "肩を叩く"
        case .talk: "話しかける"
        case .surprise: "驚かせる"
        case .cheer: "応援する"
        case .highFive: "ハイタッチ"
        case .silentPressure: "無言で圧"
        }
    }

    var symbolName: String {
        switch self {
        case .tapShoulder: "hand.tap"
        case .talk: "bubble.left"
        case .surprise: "exclamationmark.bubble"
        case .cheer: "hands.clap"
        case .highFive: "hand.raised"
        case .silentPressure: "eye"
        }
    }
}

/// 前に並んでいる人の正体。プレイヤーには直接見せない。
enum EncounterTrait: String, CaseIterable, Sendable {
    case hurried
    case shortTempered
    case cheerful
    case guarded
    case training
    case earphones
    case withChild
    case watchingStaff

    /// 見て取れる仕草。ここから正体を推測してもらう。
    ///
    /// 「短気です」のように答えそのものは書かない。
    var behaviors: [String] {
        switch self {
        case .hurried: [
            "何度も時計を見ている",
            "つま先で地面を叩いている",
            "前が動くたびに身を乗り出す",
            "電話で「あと少しで着く」と話している"
        ]
        case .shortTempered: [
            "眉間にしわが寄ったままだ",
            "舌打ちが聞こえた",
            "前の人との距離を詰めすぎている",
            "さっき誰かと揉めていた"
        ]
        case .cheerful: [
            "音楽に合わせて体を揺らしている",
            "周りの人と笑って話している",
            "リズムを取って足を鳴らしている",
            "誰かと写真を撮っていた"
        ]
        case .guarded: [
            "半歩うしろに下がって立っている",
            "鞄を体の前で抱えている",
            "こちらの気配に何度も振り返る",
            "周りと目を合わせない"
        ]
        case .training: [
            "腕を組むと上腕が盛り上がる",
            "プロテインの容器が鞄から覗いている",
            "待ち時間に軽くスクワットしている",
            "肩を回して筋を伸ばしている"
        ]
        case .earphones: [
            "大きなヘッドホンをつけている",
            "呼びかけに一切反応しない",
            "音漏れがここまで聞こえる",
            "目を閉じて頷いている"
        ]
        case .withChild: [
            "子どもの手をしっかり握っている",
            "子どもが飽きてぐずり始めた",
            "ベビーカーを押している",
            "子どもに小声で何か言い聞かせている"
        ]
        case .watchingStaff: [
            "係員のほうを何度も気にしている",
            "整理券を握りしめている",
            "列の規則が書かれた看板を読み込んでいる",
            "誰かが割り込むたびに顔をしかめる"
        ]
        }
    }

    /// 効きやすい行動。ひとつに絞らないので、読みが外れても道はある。
    var favorable: Set<EncounterAction> {
        switch self {
        case .hurried: [.talk, .silentPressure]
        case .shortTempered: [.cheer, .silentPressure]
        case .cheerful: [.highFive, .cheer]
        case .guarded: [.talk, .cheer]
        case .training: [.cheer, .highFive]
        case .earphones: [.tapShoulder, .surprise]
        case .withChild: [.cheer, .talk]
        case .watchingStaff: [.talk, .highFive]
        }
    }

    /// やってはいけない行動。
    var forbidden: Set<EncounterAction> {
        switch self {
        case .hurried: [.highFive]
        case .shortTempered: [.tapShoulder, .surprise]
        case .cheerful: [.silentPressure]
        case .guarded: [.surprise, .tapShoulder]
        case .training: [.silentPressure]
        case .earphones: [.talk, .cheer]
        case .withChild: [.surprise, .silentPressure]
        case .watchingStaff: [.surprise, .silentPressure]
        }
    }
}

/// 駆け引きの結果。
struct EncounterResult: Equatable, Sendable {
    enum Grade: Equatable, Sendable {
        case triumph
        case success
        case failure
        /// 相性とは関係なく起きる、予想外の展開。
        case twist
    }

    let grade: Grade
    let message: String
    let advance: Int
    let alertDelta: Double

    var isGood: Bool { advance > 0 }
}

/// 駆け引きの場面ひとつぶん。
struct Encounter: Equatable, Sendable {
    let trait: EncounterTrait
    /// 画面に出す仕草。3つだけ見せる。
    let observations: [String]
    let seed: Int

    static func make(seed: Int) -> Encounter {
        let traits = EncounterTrait.allCases
        let trait = traits[Int(QueueEngine.unitRandom(seed, salt: 0xA1F0) * Double(traits.count)) % traits.count]

        // 仕草は毎回ちがう組み合わせで見せる。
        let pool = trait.behaviors
        let start = Int(QueueEngine.unitRandom(seed, salt: 0xB2E1) * Double(pool.count))
        let observations = (0..<3).map { pool[(start + $0) % pool.count] }

        return Encounter(trait: trait, observations: observations, seed: seed)
    }

    /// 選んだ行動の結果を決める。
    ///
    /// 相性が良くても必ず成功するわけではなく、悪くてもまれに転がる。
    /// 「正解を覚える」ゲームにしないための揺らぎ。
    func resolve(_ action: EncounterAction) -> EncounterResult {
        let roll = QueueEngine.unitRandom(seed &+ action.hashValue, salt: 0xC3D2)

        // まれに、相性と関係なく妙なことが起きる。
        if roll > 0.9 {
            return EncounterLines.twist(trait: trait, action: action, seed: seed)
        }

        if trait.forbidden.contains(action) {
            return EncounterLines.failure(trait: trait, action: action, seed: seed)
        }

        if trait.favorable.contains(action) {
            return roll > 0.35
                ? EncounterLines.triumph(trait: trait, action: action, seed: seed)
                : EncounterLines.success(trait: trait, action: action, seed: seed)
        }

        // どちらでもない行動。半々で軽く通る。
        return roll > 0.5
            ? EncounterLines.success(trait: trait, action: action, seed: seed)
            : EncounterLines.failure(trait: trait, action: action, seed: seed)
    }
}
