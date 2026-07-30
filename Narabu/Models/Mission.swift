import Foundation

/// 列の中で起きる短い出来事。
///
/// アイテムが尽きても手持ち無沙汰にならないよう、常にひとつ用意しておく。
/// どれも5〜20秒で終わる長さにしてある。
struct Mission: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        /// 制限時間内に指定回数タップする。
        case mash(taps: Int, seconds: Double)
        /// 動くゲージを当たり範囲で止める。
        case timing(targetWidth: Double, speed: Double)
        /// 2択に答える。
        case quiz(question: String, choices: [String], answer: Int, explanation: String)
        /// 前の人の特徴を覚えて選ぶ。
        case memory(prompt: String, choices: [String], answer: Int)
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

    /// 失敗しても止まらないよう、わずかに進める。
    var consolationReward: Int { 0 }
    var consolationCoins: Int { max(1, coins / 5) }
}

enum MissionFactory {
    private static let quizzes: [(String, [String], Int, String)] = [
        ("列を離れてトイレに行くとき、正しいのは？",
         ["前後の人に一言伝える", "黙って抜ける"], 0,
         "戻る場所がなくなるので、一言が要る。"),
        ("整理券を配り始めた。まずやることは？",
         ["受け取ってから並び直す", "受け取らずに前へ進む"], 0,
         "整理券がないと、そもそも数えてもらえない。"),
        ("前の人が荷物を落とした。どうする？",
         ["拾って渡す", "見なかったことにする"], 0,
         "拾うと場所を譲ってもらえることがある。"),
        ("割り込んできた人がいる。正しい対応は？",
         ["最後尾を教える", "自分も割り込む"], 0,
         "自分も割り込むと、後ろ全員から睨まれる。"),
        ("列が二手に分かれた。どちらに進む？",
         ["係の人に聞く", "人が多いほうへ行く"], 0,
         "多いほうが正しいとは限らない。"),
        ("後ろの人が「先に行っていい」と言ってきた。",
         ["礼を言って前に出る", "断って順番を守る"], 0,
         "厚意は受け取っていい。列の総数は変わらない。")
    ]

    private static let memoryPrompts: [(String, [String], Int)] = [
        ("さっき前を通った店員が持っていたのは？", ["整理券の束", "モップ", "段ボール"], 0),
        ("前の人が読んでいた本の色は？", ["青", "赤", "黄"], 0),
        ("列の横を走っていったのは？", ["犬", "子ども", "配達員"], 0),
        ("さっき聞こえたアナウンスの内容は？", ["最後尾の案内", "閉店の予告", "落とし物"], 0)
    ]

    /// 次のミッションをひとつ作る。
    ///
    /// - Parameter seed: 同じ状況では同じミッションが出るようにするための種。
    static func make(seed: Int, stage: Stage) -> Mission {
        // 進むほど、少しだけ多く報われる。
        let scale = max(1, stage.queueLength / 60)
        let kindRoll = Int(QueueEngine.unitRandom(seed, salt: 0x3A11) * 5)

        switch kindRoll {
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

        case 2:
            let quiz = quizzes[Int(QueueEngine.unitRandom(seed, salt: 0x5C33) * Double(quizzes.count)) % quizzes.count]
            return Mission(
                id: UUID(),
                title: "列のルール",
                instruction: "正しいほうを選ぶ",
                kind: .quiz(question: quiz.0, choices: quiz.1, answer: quiz.2, explanation: quiz.3),
                reward: 3 + scale,
                coins: 26
            )

        case 3:
            let memory = memoryPrompts[Int(QueueEngine.unitRandom(seed, salt: 0x6D44) * Double(memoryPrompts.count)) % memoryPrompts.count]
            return Mission(
                id: UUID(),
                title: "さっきの出来事",
                instruction: "覚えているほうを選ぶ",
                kind: .memory(prompt: memory.0, choices: memory.1, answer: memory.2),
                reward: 3 + scale,
                coins: 26
            )

        default:
            let length = 3 + Int(QueueEngine.unitRandom(seed, salt: 0x7E55) * 2)
            let order = (0..<length).map { step -> QueueAction in
                let index = Int(QueueEngine.unitRandom(seed &+ step &* 97, salt: 0x8F66) * Double(QueueAction.allCases.count))
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
