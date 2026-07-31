import Foundation

/// 駆け引きの結果に付ける言葉と、進む人数。
///
/// ここが面白さの中心なので、相手と行動の組み合わせごとに書き分ける。
/// 数字だけ動いても何も面白くない。
enum EncounterLines {
    // MARK: - 大成功

    static func triumph(trait: EncounterTrait, action: EncounterAction, seed: Int) -> EncounterResult {
        let (message, advance): (String, Int) = switch (trait, action) {
        case (.cheerful, .highFive):
            ("いい音が鳴った。意気投合して、連れの人たちごと前に通してくれた。", 8)
        case (.cheerful, .cheer):
            ("盛り上がって踊り出した。周りが引いて道が空いた。", 7)
        case (.training, .cheer):
            ("その気になってポージングを始めた。人だかりができて、その隙に前へ出た。", 12)
        case (.training, .highFive):
            ("渾身のハイタッチで手が痺れた。「兄弟」と呼ばれ、前に入れてもらえた。", 9)
        case (.hurried, .talk):
            ("「向こうの列のほうが早いらしいですよ」と伝えたら、本当に移っていった。", 6)
        case (.hurried, .silentPressure):
            ("じっと見ていたら、耐えきれず「お先にどうぞ」と言われた。", 5)
        case (.shortTempered, .cheer):
            ("褒めちぎったら急に照れ出した。「まあ、行けよ」と通された。", 7)
        case (.shortTempered, .silentPressure):
            ("目を逸らさずにいたら、向こうが折れて場所を空けた。", 6)
        case (.guarded, .talk):
            ("天気の話から始めたら警戒が解けた。世間話のまま前に通された。", 6)
        case (.guarded, .cheer):
            ("さりげなく持ち物を褒めたら、はにかんで半歩下がってくれた。", 5)
        case (.earphones, .tapShoulder):
            ("肩を叩いたら片耳を外した。用件を伝えたら快く譲ってくれた。", 6)
        case (.earphones, .surprise):
            ("驚いてヘッドホンを落とした。拾って渡したら大いに感謝された。", 8)
        case (.withChild, .cheer):
            ("子どもを褒めたら親が破顔した。「うちはゆっくりでいいので」と通された。", 9)
        case (.withChild, .talk):
            ("子どもの相手をしていたら、親が心底ありがたそうに前を譲ってくれた。", 7)
        case (.watchingStaff, .talk):
            ("規則の話で意気投合した。「あなたは信用できる」と前に入れてくれた。", 7)
        case (.watchingStaff, .highFive):
            ("なぜか手を合わせて笑い出した。緊張が解けたらしい。", 6)
        default:
            ("思いのほか噛み合った。すんなり前に通してもらえた。", 5)
        }

        return EncounterResult(
            grade: .triumph,
            message: message,
            advance: advance + Int(QueueEngine.unitRandom(seed, salt: 0xD4C3) * 3),
            alertDelta: -4
        )
    }

    // MARK: - 成功

    static func success(trait: EncounterTrait, action: EncounterAction, seed: Int) -> EncounterResult {
        let message: String = switch action {
        case .tapShoulder: "振り返って、軽く場所を空けてくれた。"
        case .talk: "短い受け答えのあと、少しだけ詰めてくれた。"
        case .surprise: "驚いた拍子に半歩ずれた。その分だけ前に出た。"
        case .cheer: "照れくさそうにしながら、前に詰めてくれた。"
        case .highFive: "ぎこちないハイタッチだったが、悪い気はしなかったらしい。"
        case .silentPressure: "視線に気づいて、居心地悪そうに前へ詰めた。"
        }

        return EncounterResult(
            grade: .success,
            message: message,
            advance: 2 + Int(QueueEngine.unitRandom(seed, salt: 0xE5B4) * 3),
            alertDelta: action == .silentPressure ? 3 : -1
        )
    }

    // MARK: - 失敗

    static func failure(trait: EncounterTrait, action: EncounterAction, seed: Int) -> EncounterResult {
        let (message, advance, alert): (String, Int, Double) = switch (trait, action) {
        case (.shortTempered, .tapShoulder):
            ("「触るな」と睨まれた。周りの視線まで冷たくなった。", -1, 18)
        case (.shortTempered, .surprise):
            ("怒鳴り返された。完全に敵に回してしまった。", -2, 22)
        case (.guarded, .surprise):
            ("悲鳴を上げられ、係員が飛んできた。後ろまで戻された。", -4, 26)
        case (.guarded, .tapShoulder):
            ("身をこわばらせて、はっきりと距離を取られた。", -1, 14)
        case (.earphones, .talk), (.earphones, .cheer):
            ("まったく届いていない。声を張っただけ疲れた。", 0, 2)
        case (.withChild, .surprise):
            ("子どもが泣き出した。周囲から一斉に睨まれた。", -2, 24)
        case (.withChild, .silentPressure):
            ("親が子どもを庇うように立ちはだかった。完全に警戒された。", -1, 16)
        case (.watchingStaff, .surprise), (.watchingStaff, .silentPressure):
            ("係員に報告された。名前を控えられた気がする。", -2, 25)
        case (.hurried, .highFive):
            ("「そんな暇ないので」と手を払われた。", 0, 6)
        case (.cheerful, .silentPressure):
            ("じっと見ていたら「なんすか？」と真顔で返された。気まずい。", 0, 8)
        case (.training, .silentPressure):
            ("見つめ合う形になり、なぜか腕相撲を挑まれて負けた。", -1, 6)
        default:
            ("反応が薄い。特に何も起きなかった。", 0, 4)
        }

        return EncounterResult(grade: .failure, message: message, advance: advance, alertDelta: alert)
    }

    // MARK: - 予想外

    /// 相性とは関係なく、まれに起きること。良いことも悪いこともある。
    static func twist(trait: EncounterTrait, action: EncounterAction, seed: Int) -> EncounterResult {
        let twists: [(String, Int, Double)] = [
            ("前の人が突然歌い出した。周りが一斉に距離を取り、道ができた。", 11, 0),
            ("前の人の電話が鳴り、「今すぐ来い」と言われて列を去っていった。", 6, 0),
            ("前の人が財布を落とした。拾って渡したら、深々と礼をして前に通してくれた。", 8, -6),
            ("前の人が「あなた、どこかで会いましたよね」と言い出した。会っていない。", 3, 0),
            ("前の人が急に自分の人生を語り始めた。長い。聞き終える頃には少し進んでいた。", 4, -3),
            ("前の人が連れと入れ替わった。話が振り出しに戻った。", 0, 0),
            ("前の人が並ぶ理由を忘れたと言って、列を離れていった。", 5, 0),
            ("前の人が「実は自分もさっき割り込んだ」と告白してきた。共犯になった。", 4, 6),
            ("後ろの人が「早く行けよ」と言ってきた。気まずさで一歩前に出た。", 2, 4),
            ("前の人がこちらの真似を始めた。無限に続きそうなのでやめた。", 1, 2)
        ]

        let index = Int(QueueEngine.unitRandom(seed &+ action.hashValue, salt: 0xF6A5) * Double(twists.count))
        let twist = twists[min(index, twists.count - 1)]

        return EncounterResult(
            grade: .twist,
            message: twist.0,
            advance: twist.1,
            alertDelta: twist.2
        )
    }
}
