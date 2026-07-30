import Foundation

/// 景品の一覧。どれを引いても等しく価値がない。
enum PrizeCatalog {
    static let all: [Prize] = [
        // ふつう
        Prize(id: "wet-glove", name: "濡れた軍手", note: "片方だけです。乾かせば使えます。", rarity: .ordinary),
        Prize(id: "shoehorn", name: "他人の靴べら", note: "持ち主は不明です。", rarity: .ordinary),
        Prize(id: "expired-salt", name: "賞味期限が昨日までの塩", note: "塩に賞味期限はありませんが、書いてあります。", rarity: .ordinary),
        Prize(id: "old-receipt", name: "1998年のレシート", note: "合計380円です。", rarity: .ordinary),
        Prize(id: "lukewarm-water", name: "少しぬるい水", note: "冷やせば冷たくなります。", rarity: .ordinary),
        Prize(id: "bottle-cap", name: "ペットボトルのキャップ", note: "本体はありません。", rarity: .ordinary),
        Prize(id: "bent-spoon", name: "曲がったスプーン", note: "曲がっているだけで、特に力はありません。", rarity: .ordinary),
        Prize(id: "rusty-pin", name: "錆びた画鋲", note: "刺さります。お気をつけください。", rarity: .ordinary),
        Prize(id: "short-string", name: "中途半端な長さの紐", note: "結ぶには足りず、捨てるには長いです。", rarity: .ordinary),
        Prize(id: "pebble", name: "そのへんの小石", note: "そのへんで拾いました。", rarity: .ordinary),
        Prize(id: "half-eraser", name: "3分の1だけ使われた消しゴム", note: "残りはお使いいただけます。", rarity: .ordinary),
        Prize(id: "single-chopstick", name: "割り箸（片方だけ）", note: "もう片方は前の方が持って帰られました。", rarity: .ordinary),
        Prize(id: "damp-manual", name: "湿った説明書", note: "何の説明書かは判読できません。", rarity: .ordinary),
        Prize(id: "expired-coupon", name: "期限切れのクーポン", note: "3年前まで有効でした。", rarity: .ordinary),
        Prize(id: "broken-rubber-band", name: "千切れた輪ゴム", note: "結べば使えなくもありません。", rarity: .ordinary),
        Prize(id: "blank-survey", name: "空欄のアンケート用紙", note: "ご記入は不要です。回収もしません。", rarity: .ordinary),

        // ちょっと変
        Prize(id: "wrong-key", name: "どこかの部屋の鍵", note: "この建物のものではありません。", rarity: .odd),
        Prize(id: "used-origami", name: "一度ひらかれた折り紙", note: "折り目から鶴だったと思われます。", rarity: .odd),
        Prize(id: "faded-stamp", name: "名前の消えた印鑑", note: "押しても丸だけが出ます。", rarity: .odd),
        Prize(id: "unreadable-memo", name: "読めない字のメモ", note: "急いで書かれたようです。", rarity: .odd),
        Prize(id: "dead-remote", name: "電池の入っていないリモコン", note: "対応する機器は現存しません。", rarity: .odd),
        Prize(id: "empty-envelope", name: "中身のない封筒", note: "封は開いていました。", rarity: .odd),
        Prize(id: "sloppy-crane", name: "誰かが折った鶴（雑）", note: "首がありません。", rarity: .odd),
        Prize(id: "unused-single-sock", name: "片方だけの靴下（未使用）", note: "左右は不明です。", rarity: .odd),
        Prize(id: "silent-whistle", name: "音の出ない笛", note: "壊れてはいません。", rarity: .odd),
        Prize(id: "unknown-screw", name: "ネジ（用途不明）", note: "何かから外れたものです。", rarity: .odd),
        Prize(id: "sealed-jar", name: "開かない瓶", note: "中身は見えません。", rarity: .odd),
        Prize(id: "coverless-book", name: "表紙のない本", note: "最初の40ページもありません。", rarity: .odd),
        Prize(id: "stopped-watch", name: "止まった腕時計", note: "11時42分を指しています。", rarity: .odd),
        Prize(id: "broken-ruler", name: "端の折れた定規", note: "3cmから測れます。", rarity: .odd),
        Prize(id: "yesterday-forecast", name: "昨日の天気予報", note: "よく当たっていました。", rarity: .odd),
        Prize(id: "partial-bandage", name: "使いかけの絆創膏", note: "未使用の部分だけをお渡しします。", rarity: .odd),

        // なぜか貴重
        Prize(id: "bottled-sigh", name: "誰かのため息（瓶詰め）", note: "開封すると失われます。", rarity: .inexplicable),
        Prize(id: "first-love", name: "誰かの初恋の記憶（伝聞）", note: "本人から聞いた話ではありません。", rarity: .inexplicable),
        Prize(id: "unrung-alarm", name: "一度も鳴らなかった目覚まし", note: "鳴る前に毎回起きたそうです。", rarity: .inexplicable),
        Prize(id: "sweet-potato-smell", name: "冷めた石焼き芋の匂い", note: "芋は含まれません。", rarity: .inexplicable),
        Prize(id: "bed-hair-photo", name: "知らない人の寝癖の写真", note: "本人の許可は得ています。", rarity: .inexplicable),
        Prize(id: "cut-hair", name: "誰かが散髪した髪（少量）", note: "衛生上の問題はありません。", rarity: .inexplicable),
        Prize(id: "dead-button", name: "押しても何も起きないボタン", note: "配線はされています。", rarity: .inexplicable),
        Prize(id: "one-second", name: "1秒", note: "すでに経過しました。", rarity: .inexplicable)
    ]

    static func prize(for id: String) -> Prize? {
        all.first { $0.id == id }
    }

    /// 周回ごとに受け取る景品は決まっている。並び直しても引き直しはできない。
    static func prize(forLap lap: Int, joinedAt: Date) -> Prize {
        let seed = lap &* 7_919 &+ Int(joinedAt.timeIntervalSince1970) / 86_400
        let index = Int(QueueEngine.unitRandom(seed, salt: 0x2B0F) * Double(all.count))
        return all[min(index, all.count - 1)]
    }
}
