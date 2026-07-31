import Foundation

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
            }
        }
    }

    let id: UUID
    let kind: Kind
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
    /// 出しうるミッションの型。数値は難度で作り分ける。
    private enum Family: CaseIterable {
        case timing, mash, swipe, jump, dodge, escalator, hide, align

        /// 場所ごとの出やすさ。その場所らしいものを多めに出す。
        func weight(for stage: Stage) -> Double {
            switch (self, stage.id) {
            case (.timing, _): 14
            case (.mash, _): 10
            case (.swipe, _): 10
            case (.jump, 2), (.jump, 6): 12      // 荷物の多い場所
            case (.dodge, _): 8
            case (.escalator, 4), (.escalator, 6): 12   // 施設の中
            case (.hide, 5), (.hide, 4): 12     // 係員の目が厳しい場所
            case (.align, 5), (.align, 6): 12   // 整理券が要る場所
            case (.jump, _), (.escalator, _), (.hide, _), (.align, _): 5
            }
        }
    }

    /// 次のミッションをひとつ作る。
    ///
    /// - Parameter seed: 同じ状況では同じミッションが出るようにするための種。
    static func make(seed: Int, stage: Stage) -> Mission {
        // 進むほど、少しだけ多く報われる。
        let scale = max(1, stage.queueLength / 60)
        // 後ろのステージほど、わずかに難しくする。
        let difficulty = min(0.6, Double(stage.id - 1) * 0.09)

        let family = pickFamily(seed: seed, stage: stage)
        let kind = makeKind(family, seed: seed, difficulty: difficulty)

        return Mission(
            id: UUID(),
            kind: kind,
            reward: 3 + scale + (family == .dodge || family == .hide ? 1 : 0),
            coins: 24 + Int(difficulty * 20)
        )
    }

    private static func pickFamily(seed: Int, stage: Stage) -> Family {
        let weights = Family.allCases.map { $0.weight(for: stage) }
        let total = weights.reduce(0, +)
        var roll = QueueEngine.unitRandom(seed, salt: 0x3A11) * total

        for (family, weight) in zip(Family.allCases, weights) {
            roll -= weight
            if roll <= 0 { return family }
        }
        return .timing
    }

    private static func makeKind(_ family: Family, seed: Int, difficulty: Double) -> Mission.Kind {
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
        }
    }
}
