import Foundation

/// 並んでいる人の様子。どのアクションが効くかはこれで決まる。
///
/// プレイヤーが当てずっぽうにならないよう、様子は必ず画面に出す。
/// 見て考えれば正解が分かる、というのがこのゲームの手応えになる。
enum Personality: String, CaseIterable, Sendable {
    case chatty
    case wary
    case hurried
    case sleepy
    case grumpy
    case kind
    case cheerful
    case distracted
    case absorbed
    case tourist

    var label: String {
        switch self {
        case .chatty: "おしゃべり好き"
        case .wary: "警戒心が強い"
        case .hurried: "急いでいる"
        case .sleepy: "眠そう"
        case .grumpy: "怒りっぽい"
        case .kind: "親切そう"
        case .cheerful: "ノリがいい"
        case .distracted: "スマホに集中"
        case .absorbed: "考えごと中"
        case .tourist: "旅行者"
        }
    }

    /// 見た目から読み取れる手がかり。これが正解を推測する材料になる。
    var hint: String {
        switch self {
        case .chatty: "誰かと話したそうにこちらを見ている"
        case .wary: "半歩うしろに下がっていて、触られるのを嫌がりそう"
        case .hurried: "何度も時計を見て、いらいらしている"
        case .sleepy: "うとうとして、今にも倒れそう"
        case .grumpy: "眉間にしわを寄せている。触ると怒られそう"
        case .kind: "困っている人に席を譲っていた"
        case .cheerful: "音楽に合わせて体を揺らしている"
        case .distracted: "画面に見入っていて、声が届いていない"
        case .absorbed: "本から目を離さない。静かに声をかけたい"
        case .tourist: "地図を広げて、誰かに聞きたそうにしている"
        }
    }

    /// どう攻めればいいかの手がかり。
    ///
    /// 正解そのものではなく、「こう出ると通りやすい」という傾向を伝える。
    /// ただの説明で終わらせず、選ぶ材料になるようにする。
    var tactic: String {
        switch self {
        case .chatty: "話し相手を探している。声をかければ乗ってくる"
        case .wary: "触れられるのを嫌がる。褒めて距離を縮めたい"
        case .hurried: "先を急いでいる。理由をつけて頼めば譲りやすい"
        case .sleepy: "意識が飛んでいる。軽く触れれば起きる"
        case .grumpy: "機嫌が悪い。持ち上げるのが一番安全"
        case .kind: "人がよさそう。素直に頼めば応じてくれる"
        case .cheerful: "テンションが高い。勢いに乗るのが早い"
        case .distracted: "声は届かない。物理的に気づかせるしかない"
        case .absorbed: "集中している。静かに声をかけたい"
        case .tourist: "困っている。助けると恩を返してくれる"
        }
    }

    /// いちばん効くアクション。
    var best: QueueAction {
        switch self {
        case .chatty, .absorbed, .tourist, .hurried: .talk
        case .wary, .kind, .grumpy: .cheer
        case .cheerful: .highFive
        case .sleepy, .distracted: .tapShoulder
        }
    }

    /// やってはいけないアクション。
    var worst: QueueAction {
        switch self {
        case .chatty: .surprise
        case .wary: .tapShoulder
        case .hurried: .highFive
        case .sleepy: .surprise
        case .grumpy: .tapShoulder
        case .kind: .surprise
        case .cheerful: .surprise
        case .distracted: .cheer
        case .absorbed: .surprise
        case .tourist: .surprise
        }
    }

    /// うまくいったときの言葉。
    func successMessage(for action: QueueAction) -> String {
        switch self {
        case .chatty: "話が弾んだ。「お先にどうぞ」と譲ってくれた。"
        case .wary: "警戒が解けた。少し前に詰めてくれた。"
        case .hurried: "「先に行っていいですよ」と急いで出ていった。"
        case .sleepy: "はっと目を覚まして、前に詰めた。"
        case .grumpy: "機嫌が直った。ぶっきらぼうに場所を空けてくれた。"
        case .kind: "にっこり笑って、場所を譲ってくれた。"
        case .cheerful: "いい音が鳴った。ノリで前に通してくれた。"
        case .distracted: "画面から顔を上げて、慌てて前に詰めた。"
        case .absorbed: "本を閉じて、静かに場所を空けてくれた。"
        case .tourist: "道を教えたお礼に、前に入れてくれた。"
        }
    }

    /// 失敗したときの言葉。
    func failureMessage(for action: QueueAction) -> String {
        if action == worst {
            return switch self {
            case .sleepy: "飛び上がって驚かれた。露骨に距離を取られた。"
            case .grumpy: "「触るな」と怒鳴られた。後ろに下がるしかなかった。"
            case .wary: "身をこわばらせて、警戒されてしまった。"
            case .distracted: "応援されても意味が分からず、無視された。"
            case .hurried: "急いでいるのに、と睨まれた。"
            default: "完全に裏目に出た。空気が悪くなった。"
            }
        }
        return "反応が薄い。特に何も起きなかった。"
    }
}
