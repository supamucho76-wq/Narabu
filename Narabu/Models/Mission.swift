import Foundation

/// 列の中で起きる短い出来事。
///
/// アイテムが尽きても手持ち無沙汰にならないよう、常にひとつ用意しておく。
/// 操作と結果が直に結びつくものだけを置く。
/// 読ませて答えさせるものや、正解を覚えて押すだけのものは面白くならなかったので入れない。
struct Mission: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        /// 動くゲージを当たり範囲で止める。指の反応がそのまま結果になる。
        case timing(targetWidth: Double, speed: Double)
        /// 制限時間内に指定回数タップする。
        case mash(taps: Int, seconds: Double)
    }

    let id: UUID
    let title: String
    /// 何をすればいいか。
    let instruction: String
    let kind: Kind
    /// 達成したときに進む人数。
    let reward: Int
    /// 達成したときのコイン。
    let coins: Int

    /// 失敗しても止まらないよう、わずかに報いる。
    var consolationReward: Int { 0 }
    var consolationCoins: Int { max(1, coins / 5) }
}

enum MissionFactory {
    /// 次のミッションをひとつ作る。
    ///
    /// - Parameter seed: 同じ状況では同じミッションが出るようにするための種。
    static func make(seed: Int, stage: Stage) -> Mission {
        // 進むほど、少しだけ多く報われる。
        let scale = max(1, stage.queueLength / 60)

        // タイミングのほうが手応えがあるので、こちらを多めに出す。
        if QueueEngine.unitRandom(seed, salt: 0x3A11) < 0.65 {
            // 進むほど、当たり範囲が狭く速くなる。
            let difficulty = min(0.5, Double(stage.id - 1) * 0.06)
            return Mission(
                id: UUID(),
                title: "詰めるタイミング",
                instruction: "列が動いた瞬間に止める",
                kind: .timing(
                    targetWidth: max(0.10, 0.22 - difficulty * 0.2),
                    speed: 1.0 + difficulty
                ),
                reward: 4 + scale,
                coins: 30
            )
        }

        let taps = 12 + Int(QueueEngine.unitRandom(seed, salt: 0x4B22) * 10)
        return Mission(
            id: UUID(),
            title: "人混みを抜ける",
            instruction: "\(taps)回タップして、隙間をこじ開ける",
            kind: .mash(taps: taps, seconds: 6),
            reward: 3 + scale,
            coins: 24
        )
    }
}
