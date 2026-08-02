import Foundation

/// 遊びかたの大分類。
///
/// 数値の違いではなく、**指の動かしかたが違うもの**を1種類として数える。
/// 同じものが続かないようにする判定も、ここを見て行う。
enum MissionFamily: CaseIterable, Sendable {
    case timing, mash, swipe, jump, dodge, escalator, hide, align
    case hold, pluck, weave, trace, balance

    /// 場所ごとの出やすさ。その場所らしいものを多めに出す。
    ///
    /// 0にはしない。どのステージでも全種類に当たる可能性を残しておく。
    func weight(for stage: Stage) -> Double {
        let base: Double = 10

        switch (self, stage.id) {
        case (.timing, _): return 11
        case (.jump, 2), (.jump, 6): return 16          // 荷物の多い場所
        case (.escalator, 4), (.escalator, 6): return 16 // 施設の中
        case (.hide, 4), (.hide, 5): return 16          // 係員の目が厳しい場所
        case (.align, 5), (.align, 6): return 16        // 整理券が要る場所
        case (.pluck, 1), (.pluck, 3): return 14        // 人がまばらで足元が見える
        case (.weave, 5), (.weave, 6): return 16        // 人が詰まっている場所
        case (.trace, 4), (.trace, 7): return 14        // 通路が入り組んだ場所
        case (.balance, 2), (.balance, 7): return 14    // 手荷物が増える場所
        case (.hold, 6), (.hold, 7): return 14          // 大荷物の場所
        default: return base
        }
    }
}

/// 列の中で起きる短い出来事。
///
/// アイテムが尽きても手持ち無沙汰にならないよう、常にひとつ用意しておく。
/// 操作と結果が直に結びつくものだけを置く。
/// 読ませて答えさせるものや、正解を覚えて押すだけのものは面白くならなかったので入れない。
struct Mission: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        /// 動くゲージを当たり範囲で止める。
        case timing(targetWidth: Double, speed: Double)
        /// 制限時間内に指定回数タップする。
        case mash(taps: Int, seconds: Double)
        /// 示された向きへ、続けてスワイプする。
        case swipe(count: Int, seconds: Double)
        /// 迫ってくる荷物を、重なった瞬間に飛び越える。
        case jump(speed: Double, window: Double)
        /// 落ちてくるものを避けながら、指定の時間だけ耐える。
        case dodge(seconds: Double)
        /// 上へこすり上げて、落ちていくゲージを押し切る。
        case escalator(seconds: Double)
        /// 見られていない隙にだけ進む。
        case hide(seconds: Double)
        /// 動く枠に整理券を合わせる。
        case align(tolerance: Double)
        /// 押し続けて伸びる目盛りを、帯の中で離す。
        case hold(target: Double, tolerance: Double)
        /// 足元に現れたものを、消える前にタップする。
        case pluck(count: Int, seconds: Double)
        /// 左右を交互にタップして、体をねじ込む。
        case weave(count: Int, seconds: Double)
        /// 曲がりくねった道を、指で外さずになぞる。
        case trace(seconds: Double, width: Double)
        /// 傾いていく荷物を、傾いた側をタップして立て直す。
        case balance(seconds: Double, drift: Double)

        /// 遊びかたが一言で分かる説明。
        var instruction: String {
            switch self {
            case .timing: "列が動いた瞬間に止める"
            case .mash(let taps, _): "\(taps)回タップして、隙間をこじ開ける"
            case .swipe: "示された向きへスワイプする"
            case .jump: "荷物が重なった瞬間に飛び越える"
            case .dodge: "落ちてくるものを避け続ける"
            case .escalator: "上へこすって駆け上がる"
            case .hide: "見られていない隙にだけ進む"
            case .align: "動く枠に整理券を合わせる"
            case .hold: "目盛りが帯に入ったら指を離す"
            case .pluck(let count, _): "現れたものを\(count)個ひろう"
            case .weave(let count, _): "左右を交互に\(count)回タップする"
            case .trace: "道から外れないよう指でなぞる"
            case .balance: "傾いた側をタップして立て直す"
            }
        }

        var title: String {
            switch self {
            case .timing: "詰めるタイミング"
            case .mash: "人混みを抜ける"
            case .swipe: "人混みを押し分ける"
            case .jump: "荷物を飛び越える"
            case .dodge: "落とし物を避ける"
            case .escalator: "エスカレーターを駆け上がる"
            case .hide: "警備員をやり過ごす"
            case .align: "整理券を見せる"
            case .hold: "荷物を担ぎ上げる"
            case .pluck: "落とし物をひろう"
            case .weave: "人の間をすり抜ける"
            case .trace: "手すりをつたう"
            case .balance: "荷物を落とさない"
            }
        }
    }

    let id: UUID
    let kind: Kind
    /// どの遊びかたなのか。同じものが続かないよう選ぶときに使う。
    let family: MissionFamily
    /// 達成したときに進む人数。
    let reward: Int
    /// 達成したときのコイン。
    let coins: Int

    var title: String { kind.title }
    var instruction: String { kind.instruction }

    /// 失敗しても止まらないよう、わずかに報いる。
    var consolationReward: Int { 0 }
    var consolationCoins: Int { max(1, coins / 5) }
}

enum MissionFactory {
    /// 直前に出たものを、何回ぶん覚えておくか。
    ///
    /// 2にしておくと「Aの次にA」も「AとBが交互に続く」も起きない。
    static let historyDepth = 2

    /// 次のミッションをひとつ作る。
    ///
    /// - Parameters:
    ///   - seed: 同じ状況では同じミッションが出るようにするための種。
    ///   - recent: 直前に出た遊びかた。ここに入っているものは選ばない。
    static func make(seed: Int, stage: Stage, recent: [MissionFamily] = []) -> Mission {
        // 進むほど、少しだけ多く報われる。
        let scale = max(1, stage.queueLength / 60)
        // 後ろのステージほど、わずかに難しくする。
        let difficulty = min(0.6, Double(stage.id - 1) * 0.09)

        let family = pickFamily(seed: seed, stage: stage, recent: recent)
        let kind = makeKind(family, seed: seed, difficulty: difficulty)

        return Mission(
            id: UUID(),
            kind: kind,
            family: family,
            reward: 3 + scale + (family == .dodge || family == .hide ? 1 : 0),
            coins: 24 + Int(difficulty * 20)
        )
    }

    /// 直前に出たものを外してから、場所ごとの重みで選ぶ。
    ///
    /// 全部除外されて選べなくなることがないよう、
    /// 候補が空になったときだけ除外をあきらめる。
    private static func pickFamily(
        seed: Int,
        stage: Stage,
        recent: [MissionFamily]
    ) -> MissionFamily {
        let blocked = Set(recent.suffix(historyDepth))
        var candidates = MissionFamily.allCases.filter { !blocked.contains($0) }
        if candidates.isEmpty { candidates = MissionFamily.allCases }

        let weights = candidates.map { $0.weight(for: stage) }
        let total = weights.reduce(0, +)
        guard total > 0 else { return candidates[0] }

        var roll = QueueEngine.unitRandom(seed, salt: 0x3A11) * total
        for (family, weight) in zip(candidates, weights) {
            roll -= weight
            if roll <= 0 { return family }
        }
        return candidates[candidates.count - 1]
    }

    private static func makeKind(
        _ family: MissionFamily,
        seed: Int,
        difficulty: Double
    ) -> Mission.Kind {
        switch family {
        case .timing:
            .timing(targetWidth: max(0.10, 0.22 - difficulty * 0.18), speed: 1.0 + difficulty)
        case .mash:
            .mash(taps: 12 + Int(QueueEngine.unitRandom(seed, salt: 0x4B22) * 10), seconds: 6)
        case .swipe:
            .swipe(count: 5 + Int(difficulty * 5), seconds: 7)
        case .jump:
            .jump(speed: 0.7 + difficulty * 0.6, window: max(0.11, 0.2 - difficulty * 0.12))
        case .dodge:
            .dodge(seconds: 6 + difficulty * 3)
        case .escalator:
            .escalator(seconds: 7)
        case .hide:
            .hide(seconds: 7 + difficulty * 2)
        case .align:
            .align(tolerance: max(0.07, 0.15 - difficulty * 0.08))
        case .hold:
            // 目標は真ん中あたりで揺らす。帯は後ろのステージほど狭い。
            .hold(
                target: 0.5 + QueueEngine.unitRandom(seed, salt: 0x5C33) * 0.32,
                tolerance: max(0.06, 0.13 - difficulty * 0.07)
            )
        case .pluck:
            .pluck(count: 5 + Int(difficulty * 4), seconds: 7)
        case .weave:
            .weave(count: 8 + Int(difficulty * 8), seconds: 7)
        case .trace:
            .trace(seconds: 5 + difficulty * 2, width: max(0.13, 0.24 - difficulty * 0.12))
        case .balance:
            .balance(seconds: 6 + difficulty * 3, drift: 0.5 + difficulty * 0.7)
        }
    }
}
