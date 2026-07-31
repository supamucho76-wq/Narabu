import Foundation

/// 列の中で起きる短い出来事。
///
/// アイテムが尽きても手持ち無沙汰にならないよう、常にひとつ用意しておく。
/// 読ませて答えさせるものは置かない。指を動かして数秒で終わるものだけにする。
struct Mission: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        /// 制限時間内に指定回数タップする。
        case mash(taps: Int, seconds: Double)
        /// 動くゲージを当たり範囲で止める。
        case timing(targetWidth: Double, speed: Double)
        /// 指定された順番でアクションを押す。
        case sequence([QueueAction])
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

        switch Int(QueueEngine.unitRandom(seed, salt: 0x3A11) * 3) {
        case 0:
            let taps = 12 + Int(QueueEngine.unitRandom(seed, salt: 0x4B22) * 10)
            return Mission(
                id: UUID(),
                title: "人混みを抜ける",
                instruction: "\(taps)回タップして、隙間をこじ開ける",
                kind: .mash(taps: taps, seconds: 6),
                reward: 3 + scale,
                coins: 24
            )

        case 1:
            return Mission(
                id: UUID(),
                title: "詰めるタイミング",
                instruction: "列が動いた瞬間に止める",
                kind: .timing(targetWidth: 0.18, speed: 1.15),
                reward: 4 + scale,
                coins: 30
            )

        default:
            let length = 3 + Int(QueueEngine.unitRandom(seed, salt: 0x7E55) * 2)
            let order = (0..<length).map { step -> QueueAction in
                let index = Int(QueueEngine.unitRandom(seed &+ step &* 97, salt: 0x8F66)
                                * Double(QueueAction.allCases.count))
                return QueueAction.allCases[min(index, QueueAction.allCases.count - 1)]
            }
            return Mission(
                id: UUID(),
                title: "手順どおりに",
                instruction: "表示された順番にボタンを押す",
                kind: .sequence(order),
                reward: 4 + scale,
                coins: 32
            )
        }
    }
}
