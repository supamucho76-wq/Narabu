import Foundation

/// 前後に並んでいる人。話しかけることはできず、ただそこにいるのが見えるだけ。
struct Neighbor: Equatable, Sendable {
    /// 「紺のダウンを着た50代くらいの男性」
    let appearance: String
    /// 「ずっと同じ本を読んでいる」
    let behavior: String
    /// 並んでいる日数。
    let daysWaiting: Int

    var waitingLabel: String {
        switch daysWaiting {
        case 0: "さっき来たばかり"
        case 1: "昨日から並んでいる"
        default: "\(daysWaiting)日並んでいる"
        }
    }
}

/// 前後の人を、並び順から決定的に作る。
///
/// 少し進むくらいでは顔ぶれは変わらないが、大きく動くと人が入れ替わる。
/// 列を離れた人がいる、ということにしている。
enum NeighborGenerator {
    private static let ages = [
        "20代前半", "20代後半", "30代くらい", "40代くらい",
        "50代くらい", "60代くらい", "年齢のわからない"
    ]

    private static let genders = ["男性", "女性", "人"]

    private static let outfits = [
        "紺のダウンを着た", "灰色のスウェットの", "きちんとしたコートの",
        "作業着のままの", "サンダル履きの", "リュックを背負った",
        "傘を杖のようにしている", "大きな紙袋を提げた", "帽子を目深にかぶった",
        "制服のような服の", "厚着しすぎている", "手ぶらの",
        "折りたたみ椅子を持ってきた", "眼鏡が曇っている", "マフラーを巻いた"
    ]

    private static let behaviors = [
        "ずっと同じ本を読んでいる",
        "さっきから一度も座っていない",
        "小声で誰かと電話している",
        "地面の一点を見ている",
        "定期的に前の様子を確認している",
        "おにぎりを食べ終わったところ",
        "折りたたみ椅子で眠っている",
        "整理券を何度も見返している",
        "ときどき列から出て、また戻ってくる",
        "スマホの充電を気にしている",
        "誰とも目を合わせない",
        "小さな声で数を数えている",
        "同じ場所を行ったり来たりしている",
        "毛布にくるまっている",
        "何かをメモに書きつけている",
        "こちらを一度だけ見た",
        "ずっと空を見上げている",
        "パズルゲームをしている",
        "静かにストレッチをしている",
        "後ろの人と何か話している"
    ]

    /// - Parameters:
    ///   - position: 自分の並び順。
    ///   - offset: 前の人なら -1、後ろの人なら +1。
    ///   - lap: 何周目か。周回が変われば顔ぶれも変わる。
    static func neighbor(at position: Int, offset: Int, lap: Int) -> Neighbor {
        // 40人ぶんくらい進むと顔ぶれが入れ替わる。
        let bucket = (position / 40) &+ offset &* 7 &+ lap &* 1_009
        let waited = Int(QueueEngine.unitRandom(bucket, salt: 0x5E17) * 12)

        return Neighbor(
            appearance: appearance(seed: bucket),
            behavior: behaviors[index(bucket, salt: 0x77B3, count: behaviors.count)],
            daysWaiting: waited
        )
    }

    private static func appearance(seed: Int) -> String {
        let outfit = outfits[index(seed, salt: 0x1A2B, count: outfits.count)]
        let age = ages[index(seed, salt: 0x3C4D, count: ages.count)]
        let gender = genders[index(seed, salt: 0x5E6F, count: genders.count)]
        return "\(outfit)\(age)\(gender)"
    }

    private static func index(_ seed: Int, salt: UInt64, count: Int) -> Int {
        min(Int(QueueEngine.unitRandom(seed, salt: salt) * Double(count)), count - 1)
    }
}
